unit uArcHrvEngine;

{_________________________________________________________________________________
Bu masaüstü uygulaması, Çin üretimi Holter EKG analiz yazılımı tarafından dışa aktarılan *.arc uzantılı ham hasta kayıt dosyalarını herhangi bir üçüncü parti kütüphaneye veya harici araca ihtiyaç duymadan doğrudan çözümlemek ve klinik düzeyde Kalp Hızı Değişkenliği (HRV) analizi yapmak amacıyla geliştirilmiştir.

Uygulama, ikili (binary) konteyner içerisindeki 3 kanallı (128 Hz, Little-Endian 16-bit) ham EKG sinyallerini ve atım işaretleyicilerini (`beats.atr`) ayrıştırır. Ektopik atımları (SVE/VE) ve rapor dışı işaretçileri otomatik filtreleyerek saf NN (Normal-to-Normal) aralıklarını izole eder; hem Zaman Alanı (Time-Domain) hem de Welch FFT tabanlı Frekans Alanı (Frequency-Domain) sirkadiyen otonom denge parametrelerini ve kalp hızı asimetrisi (HRA) parametrelerini hesaplar.
_________________________________________________________________________________}

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections;

type
  TArcEntry = record
    Name: string;
    Offset: Int64;
    Size: Cardinal;
  end;

  TBeatRecord = record
    RPeakSample: Cardinal;
    RRSamples: Cardinal;
    Reserved: Cardinal;
    BeatIndex: Cardinal;
    RawTail: array[0..19] of Byte; // Bayt 16..35 (Byte[34] = RawTail[18])
  end;

  THourlyHrvRow = record
    RecordHour: Integer;
    ClockLabel: string;
    NNCount: Integer;
    MeanHR: Double;
    SDNN: Double;
    rMSSD: Double;
    pNN50: Double;
    VLF: Double;
    LF: Double;
    HF: Double;
    LF_HF: Double;
    SympatheticPct: Double;
    ParasympatheticPct: Double;
  end;

  TFreqSummary = record
    WindowCount: Integer;
    TotalPower: Double;
    VLF: Double;
    LF: Double;
    HF: Double;
    LF_HF: Double;
    SympatheticPct: Double;
    ParasympatheticPct: Double;
  end;

  THrvReportData = record
    FileName: string;
    StartHour: Double;
    TotalRawRecords: Integer;
    ExcludedRecords: Integer; // Byte[34] = 16 (73 adet)
    ValidBeats: Integer;      // 128,291
    PureNNCount: Integer;
    EctopicCount: Integer;    // Byte[34] = 9 (3,468)
    MeanHR: Double;
    MinHR: Double;
    MaxHR: Double;
    SDNN: Double;
    SDNNIndex: Double;
    SDANN: Double;
    rMSSD: Double;
    pNN50: Double;
    TriangularIndex: Double;
    Freq24h: TFreqSummary;
    FreqDay: TFreqSummary;    // 08:00 - 22:00
    FreqNight: TFreqSummary;  // 23:00 - 06:00
    NightDayHFRatio: Double;
    CircadianIndex: Double;
    NNValuesMs: TArray<Double>;
    NNTimesSec: TArray<Double>;
    PoincareX: TArray<Double>;
    PoincareY: TArray<Double>;
    HourlyRows: TArray<THourlyHrvRow>;
    HRA_PI: Double;   // Porta İndeksi (%)
    HRA_GI: Double;   // Guzik İndeksi (%)
  end;

  TArcHrvProcessor = class
  private
    FRawBytes: TBytes;
    FEntries: TArray<TArcEntry>;
    function ExtractStartHour(DefaultHour: Double): Double;
    procedure FFT512(var Re, Im: array of Double);
    function ComputeWindowedPSD(const NNTimes, NNMs: TArray<Double>;
      StartHour: Double; PeriodFilter: Integer): TFreqSummary; // 0: All, 1: Day, 2: Night
  public
    procedure LoadFile(const AFileName: string);
    procedure ExtractAllEntriesToFolder(const ADestFolder: string);
    function GetEcgPreview(StartSec, DurationSec: Integer; out Ch1, Ch2, Ch3: TArray<Double>): Boolean;
    function Analyze(DefaultStartHour: Double = 10.0): THrvReportData;
    property Entries: TArray<TArcEntry> read FEntries;
  end;

implementation

{ TArcHrvProcessor }

procedure TArcHrvProcessor.LoadFile(const AFileName: string);
var
  FS: TFileStream;
  Pos: Int64;
  EntrySize: Cardinal;
  NameBytes: TBytes;
  NameLen, I: Integer;
  IsValidName: Boolean;
  List: TList<TArcEntry>;
  Entry: TArcEntry;
begin
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(FRawBytes, FS.Size);
    if FS.Size > 0 then
      FS.ReadBuffer(FRawBytes[0], FS.Size);
  finally
    FS.Free;
  end;

  List := TList<TArcEntry>.Create;
  try
    Pos := 86;
    while Pos + 264 <= Length(FRawBytes) do
    begin
      Move(FRawBytes[Pos], EntrySize, 4);
      NameLen := 0;
      while (NameLen < 260) and (FRawBytes[Pos + 4 + NameLen] <> 0) do
        Inc(NameLen);

      IsValidName := (NameLen >= 3) and (NameLen <= 64);
      if IsValidName then
      begin
        for I := 0 to NameLen - 1 do
          if (FRawBytes[Pos + 4 + I] < 32) or (FRawBytes[Pos + 4 + I] >= 127) then
          begin
            IsValidName := False;
            Break;
          end;
      end;

      if (not IsValidName) or (Pos + 264 + Int64(EntrySize) > Length(FRawBytes)) then
        Break;

      SetLength(NameBytes, NameLen);
      Move(FRawBytes[Pos + 4], NameBytes[0], NameLen);
      Entry.Name := TEncoding.ASCII.GetString(NameBytes);
      Entry.Offset := Pos + 264;
      Entry.Size := EntrySize;
      List.Add(Entry);

      Pos := Pos + 264 + Int64(EntrySize);
    end;
    FEntries := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TArcHrvProcessor.ExtractAllEntriesToFolder(const ADestFolder: string);
var
  Entry: TArcEntry;
  OutPath: string;
  FS: TFileStream;
begin
  ForceDirectories(ADestFolder);
  for Entry in FEntries do
  begin
    OutPath := IncludeTrailingPathDelimiter(ADestFolder) + Entry.Name;
    FS := TFileStream.Create(OutPath, fmCreate);
    try
      if Entry.Size > 0 then
        FS.WriteBuffer(FRawBytes[Entry.Offset], Entry.Size);
    finally
      FS.Free;
    end;
  end;
end;

function TArcHrvProcessor.ExtractStartHour(DefaultHour: Double): Double;
var
  Entry: TArcEntry;
  HeaderText: string;
  I, H, M, S: Integer;
begin
  Result := DefaultHour;
  for Entry in FEntries do
  begin
    if SameText(Entry.Name, 'patient.hea') and (Entry.Size > 8) then
    begin
      HeaderText := TEncoding.ANSI.GetString(FRawBytes, Entry.Offset, Entry.Size);
      // Basit HH:MM:SS tarayıcı
      for I := 1 to Length(HeaderText) - 7 do
      begin
        if CharInSet(HeaderText[I], ['0'..'2']) and
           CharInSet(HeaderText[I+1], ['0'..'9']) and
           (HeaderText[I+2] = ':') and
           CharInSet(HeaderText[I+3], ['0'..'5']) and
           CharInSet(HeaderText[I+4], ['0'..'9']) and
           (HeaderText[I+5] = ':') and
           CharInSet(HeaderText[I+6], ['0'..'5']) and
           CharInSet(HeaderText[I+7], ['0'..'9']) then
        begin
          H := StrToIntDef(Copy(HeaderText, I, 2), -1);
          M := StrToIntDef(Copy(HeaderText, I+3, 2), -1);
          S := StrToIntDef(Copy(HeaderText, I+6, 2), -1);
          if (H >= 0) and (H <= 23) and (M >= 0) and (S >= 0) then
            Exit(H + M / 60.0 + S / 3600.0);
        end;
      end;
    end;
  end;
end;

function TArcHrvProcessor.GetEcgPreview(StartSec, DurationSec: Integer;
  out Ch1, Ch2, Ch3: TArray<Double>): Boolean;
const
  FS_HZ = 128;
  NCH = 3;
var
  Entry: TArcEntry;
  Found: Boolean;
  ByteOffset, TotalSamples, I: Integer;
  RawU16: Word;
begin
  Result := False;
  Found := False;
  for Entry in FEntries do
    if SameText(Entry.Name, 'ecgraw.dat') then
    begin
      Found := True;
      Break;
    end;

  if not Found then Exit;

  ByteOffset := StartSec * FS_HZ * NCH * 2;
  TotalSamples := DurationSec * FS_HZ;
  if ByteOffset + (TotalSamples * NCH * 2) > Integer(Entry.Size) then
    TotalSamples := (Integer(Entry.Size) - ByteOffset) div (NCH * 2);

  if TotalSamples <= 10 then Exit;

  SetLength(Ch1, TotalSamples);
  SetLength(Ch2, TotalSamples);
  SetLength(Ch3, TotalSamples);

  for I := 0 to TotalSamples - 1 do
  begin
    // Little-Endian u2, ADC merkezi 32768, ölçek ~200 sayı/mV
    Move(FRawBytes[Entry.Offset + ByteOffset + (I * 6)], RawU16, 2);
    Ch1[I] := (Integer(RawU16) - 32768) / 200.0;

    Move(FRawBytes[Entry.Offset + ByteOffset + (I * 6) + 2], RawU16, 2);
    Ch2[I] := (Integer(RawU16) - 32768) / 200.0;

    Move(FRawBytes[Entry.Offset + ByteOffset + (I * 6) + 4], RawU16, 2);
    Ch3[I] := (Integer(RawU16) - 32768) / 200.0;
  end;
  Result := True;
end;

procedure TArcHrvProcessor.FFT512(var Re, Im: array of Double);
const
  N = 512;
var
  I, J, K, M, Step: Integer;
  TempRe, TempIm, Angle, WRe, WIm, URe, UIm, TRe, TIm: Double;
begin
  // Bit-reversal permütasyonu
  J := 0;
  for I := 0 to N - 2 do
  begin
    if I < J then
    begin
      TempRe := Re[I]; Re[I] := Re[J]; Re[J] := TempRe;
      TempIm := Im[I]; Im[I] := Im[J]; Im[J] := TempIm;
    end;
    K := N shr 1;
    while (K <= J) and (K > 0) do
    begin
      Dec(J, K);
      K := K shr 1;
    end;
    Inc(J, K);
  end;

  // Cooley-Tukey kelebek hesaplamaları
  Step := 1;
  while Step < N do
  begin
    M := Step shl 1;
    for K := 0 to Step - 1 do
    begin
      Angle := -Pi * K / Step;
      WRe := Cos(Angle);
      WIm := Sin(Angle);
      I := K;
      while I < N do
      begin
        URe := Re[I];
        UIm := Im[I];
        TRe := WRe * Re[I + Step] - WIm * Im[I + Step];
        TIm := WRe * Im[I + Step] + WIm * Re[I + Step];
        Re[I] := URe + TRe;
        Im[I] := UIm + TIm;
        Re[I + Step] := URe - TRe;
        Im[I + Step] := UIm - TIm;
        Inc(I, M);
      end;
    end;
    Step := M;
  end;
end;

function TArcHrvProcessor.ComputeWindowedPSD(const NNTimes, NNMs: TArray<Double>;
  StartHour: Double; PeriodFilter: Integer): TFreqSummary;
const
  FS_INTERP = 4.0;
  NFFT = 512;
var
  TotalDur, T0, T1, ClkH, MeanVal, WinPowerSum: Double;
  NWin, W, I, K, Idx0, Idx1, SegLen, ULen, CurIdx: Integer;
  TUniform, YUniform, HannWin, PSD: array[0..1199] of Double;
  Re, Im: array[0..NFFT - 1] of Double;
  VlfSum, LfSum, HfSum, TpSum, LfNuSum, HfNuSum: Double;
  VlfW, LfW, HfW, Freq, Df, TVal, Alpha: Double;
  ValidWins, InPeriodCount, TotalInWin: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Length(NNTimes) < 200 then Exit;

  TotalDur := NNTimes[High(NNTimes)] - NNTimes[0];
  NWin := Trunc(TotalDur / 300.0);
  if NWin <= 0 then Exit;

  VlfSum := 0; LfSum := 0; HfSum := 0; TpSum := 0;
  LfNuSum := 0; HfNuSum := 0;
  ValidWins := 0;

  // Hanning penceresi ön-hesaplama
  WinPowerSum := 0;
  for I := 0 to NFFT - 1 do
  begin
    HannWin[I] := 0.5 * (1.0 - Cos(2.0 * Pi * I / (NFFT - 1)));
    WinPowerSum := WinPowerSum + Sqr(HannWin[I]);
  end;

  Idx0 := 0;
  for W := 0 to NWin - 1 do
  begin
    T0 := NNTimes[0] + W * 300.0;
    T1 := T0 + 300.0;

    while (Idx0 < Length(NNTimes)) and (NNTimes[Idx0] < T0) do Inc(Idx0);
    Idx1 := Idx0;
    while (Idx1 < Length(NNTimes)) and (NNTimes[Idx1] < T1) do Inc(Idx1);

    SegLen := Idx1 - Idx0;
    if SegLen < 150 then Continue;

    // Gündüz (08-22) / Gece (23-06) filtresi
    if PeriodFilter > 0 then
    begin
      InPeriodCount := 0;
      TotalInWin := SegLen;
      for I := Idx0 to Idx1 - 1 do
      begin
        ClkH := FMod(StartHour + NNTimes[I] / 3600.0, 24.0);
        if (PeriodFilter = 1) and (ClkH >= 8.0) and (ClkH < 22.0) then Inc(InPeriodCount);
        if (PeriodFilter = 2) and ((ClkH >= 23.0) or (ClkH < 6.0)) then Inc(InPeriodCount);
      end;
      if (InPeriodCount / TotalInWin) < 0.8 then Continue;
    end;

    // 4 Hz düzgün zaman eksenine enterpolasyon
    ULen := Trunc((NNTimes[Idx1 - 1] - NNTimes[Idx0]) * FS_INTERP);
    if (ULen < NFFT) or (ULen > 1200) then Continue;

    CurIdx := Idx0;
    MeanVal := 0;
    for I := 0 to ULen - 1 do
    begin
      TVal := NNTimes[Idx0] + I / FS_INTERP;
      while (CurIdx < Idx1 - 2) and (NNTimes[CurIdx + 1] < TVal) do Inc(CurIdx);
      if NNTimes[CurIdx + 1] > NNTimes[CurIdx] then
        Alpha := (TVal - NNTimes[CurIdx]) / (NNTimes[CurIdx + 1] - NNTimes[CurIdx])
      else
        Alpha := 0;
      YUniform[I] := NNMs[CurIdx] + Alpha * (NNMs[CurIdx + 1] - NNMs[CurIdx]);
      MeanVal := MeanVal + YUniform[I];
    end;
    MeanVal := MeanVal / ULen;

    // Detrend + Welch (2 örtüşen 512-noktalı segment)
    for K := 0 to NFFT div 2 do PSD[K] := 0;

    for I := 0 to NFFT - 1 do
    begin
      Re[I] := (YUniform[I] - MeanVal) * HannWin[I];
      Im[I] := 0;
    end;
    FFT512(Re, Im);
    for K := 0 to NFFT div 2 do
      PSD[K] := PSD[K] + (Sqr(Re[K]) + Sqr(Im[K])) / (FS_INTERP * WinPowerSum);

    for I := 0 to NFFT - 1 do
    begin
      Re[I] := (YUniform[ULen - NFFT + I] - MeanVal) * HannWin[I];
      Im[I] := 0;
    end;
    FFT512(Re, Im);
    for K := 0 to NFFT div 2 do
      PSD[K] := (PSD[K] + (Sqr(Re[K]) + Sqr(Im[K])) / (FS_INTERP * WinPowerSum)); // Tek taraflı spektrum (*2 / 2 ortalama = *1)

    Df := FS_INTERP / NFFT;
    VlfW := 0; LfW := 0; HfW := 0;
    for K := 1 to NFFT div 2 do
    begin
      Freq := K * Df;
      if (Freq >= 0.0033) and (Freq < 0.04) then VlfW := VlfW + PSD[K] * Df
      else if (Freq >= 0.04) and (Freq < 0.15) then LfW := LfW + PSD[K] * Df
      else if (Freq >= 0.15) and (Freq < 0.40) then HfW := HfW + PSD[K] * Df;
    end;

    VlfSum := VlfSum + VlfW;
    LfSum := LfSum + LfW;
    HfSum := HfSum + HfW;
    TpSum := TpSum + (VlfW + LfW + HfW);
    if (LfW + HfW) > 0 then
    begin
      LfNuSum := LfNuSum + (LfW / (LfW + HfW)) * 100.0;
      HfNuSum := HfNuSum + (HfW / (LfW + HfW)) * 100.0;
    end;
    Inc(ValidWins);
  end;

  if ValidWins > 0 then
  begin
    Result.WindowCount := ValidWins;
    Result.VLF := VlfSum / ValidWins;
    Result.LF := LfSum / ValidWins;
    Result.HF := HfSum / ValidWins;
    Result.TotalPower := TpSum / ValidWins;
    if Result.HF > 0 then Result.LF_HF := Result.LF / Result.HF;
    Result.SympatheticPct := LfNuSum / ValidWins;
    Result.ParasympatheticPct := HfNuSum / ValidWins;
  end;
end;

function TArcHrvProcessor.Analyze(DefaultStartHour: Double): THrvReportData;
const
  FS_HZ = 128.0;
var
  Entry: TArcEntry;
  Found: Boolean;
  NRec, I, ValidIdx, H, RealH, MaxBin: Integer;
  Rec: TBeatRecord;
  ValidPeaks: TArray<Cardinal>;
  ValidStatus: TArray<Byte>;
  NNList, TimeList, DiffList, SegMeans, SegStds, DayNN, NightNN: TList<Double>;
  PoincX, PoincY: TList<Double>;
  RRms, DiffMs, SumNN, SumSqDiff, SmoothSum, MinHR, MaxHR, CurHR: Double;
  IsPrevNN: Boolean;
  SegIdx, CurSeg, PnnCount, BinIdx: Integer;
  Hist: array[0..300] of Integer;
  HourlyList: TList<THourlyHrvRow>;
  HRow: THourlyHrvRow;
  HNN, HT, HDiff: TList<Double>;
  HFreq: TFreqSummary;
  ClkH: Double;
  AccelCount, DecelCount: Integer;
  DecelSqDistSum, TotalSqDistSum: Double;
  RRN, RRN1, Diff, SqDist: Double;

begin
  FillChar(Result, SizeOf(Result), 0);
  Result.StartHour := ExtractStartHour(DefaultStartHour);

  Found := False;
  for Entry in FEntries do
    if SameText(Entry.Name, 'beats.atr') then
    begin
      Found := True;
      Break;
    end;

  if not Found then
    raise Exception.Create('ARC dosyası içinde beats.atr bulunamadı.');

  NRec := Entry.Size div 36;
  Result.TotalRawRecords := NRec;

  SetLength(ValidPeaks, NRec);
  SetLength(ValidStatus, NRec);
  ValidIdx := 0;

  for I := 0 to NRec - 1 do
  begin
    Move(FRawBytes[Entry.Offset + I * 36], Rec, 36);
    // Byte[34] = RawTail[18]
    if Rec.RawTail[18] = 16 then
      Inc(Result.ExcludedRecords)
    else
    begin
      ValidPeaks[ValidIdx] := Rec.RPeakSample;
      ValidStatus[ValidIdx] := Rec.RawTail[18];
      if Rec.RawTail[18] = 9 then
        Inc(Result.EctopicCount);
      Inc(ValidIdx);
    end;
  end;
  Result.ValidBeats := ValidIdx;

  NNList := TList<Double>.Create;
  TimeList := TList<Double>.Create;
  DiffList := TList<Double>.Create;
  PoincX := TList<Double>.Create;
  PoincY := TList<Double>.Create;
  DayNN := TList<Double>.Create;
  NightNN := TList<Double>.Create;

  try
    IsPrevNN := False;
    for I := 1 to ValidIdx - 1 do
    begin
      RRms := ((ValidPeaks[I] - ValidPeaks[I - 1]) / FS_HZ) * 1000.0;
      if (ValidStatus[I] = 1) and (ValidStatus[I - 1] = 1) and (RRms >= 300.0) and (RRms <= 2000.0) then
      begin
        if IsPrevNN and (NNList.Count > 0) then
        begin
          DiffMs := RRms - NNList.Last;
          DiffList.Add(DiffMs);
          PoincX.Add(NNList.Last);
          PoincY.Add(RRms);
        end;
        NNList.Add(RRms);
        TimeList.Add(ValidPeaks[I] / FS_HZ);

        ClkH := FMod(Result.StartHour + (ValidPeaks[I] / FS_HZ) / 3600.0, 24.0);
        if (ClkH >= 8.0) and (ClkH < 22.0) then DayNN.Add(RRms);
        if (ClkH >= 23.0) or (ClkH < 6.0) then NightNN.Add(RRms);

        IsPrevNN := True;
      end
      else
        IsPrevNN := False;
    end;

    Result.NNValuesMs := NNList.ToArray;
    Result.NNTimesSec := TimeList.ToArray;
    Result.PoincareX := PoincX.ToArray;
    Result.PoincareY := PoincY.ToArray;

    // --- HRA Hesaplaması (Porta ve Guzik İndeksleri) ---
    begin
      AccelCount := 0;
      DecelCount := 0;
      DecelSqDistSum := 0.0;
      TotalSqDistSum := 0.0;

      for I := 0 to High(Result.PoincareX) do
      begin
        RRN := Result.PoincareX[I];
        RRN1 := Result.PoincareY[I];
        Diff := RRN1 - RRN;
        SqDist := (Diff * Diff) / 2.0; // Kimlik çizgisine kare uzaklık

        if Diff > 0 then // Yavaşlama (Deceleration)
        begin
          Inc(DecelCount);
          DecelSqDistSum := DecelSqDistSum + SqDist;
        end
        else if Diff < 0 then // Hızlanma (Acceleration)
          Inc(AccelCount);
        // Diff = 0 ise (eşit ardışık RR) hiçbir sayaca eklenmez

        TotalSqDistSum := TotalSqDistSum + SqDist;
      end;

      // Porta İndeksi (Hızlanma yüzdesi)
      if (AccelCount + DecelCount) > 0 then
        Result.HRA_PI := (AccelCount / (AccelCount + DecelCount)) * 100.0
      else
        Result.HRA_PI := 0;

      // Guzik İndeksi (Yavaşlama kare uzaklık yüzdesi)
      if TotalSqDistSum > 0 then
        Result.HRA_GI := (DecelSqDistSum / TotalSqDistSum) * 100.0
      else
        Result.HRA_GI := 0;
    end;
    // --- HRA Hesaplaması Sonu ---

    Result.PureNNCount := Length(Result.NNValuesMs);

    if Result.PureNNCount < 10 then Exit;

    // Ortalama, SDNN ve 8-atımlık pencere Min/Maks HR
    SumNN := 0;
    for I := 0 to Result.PureNNCount - 1 do
      SumNN := SumNN + Result.NNValuesMs[I];
    Result.MeanHR := 60000.0 / (SumNN / Result.PureNNCount);

    SumSqDiff := 0;
    for I := 0 to Result.PureNNCount - 1 do
      SumSqDiff := SumSqDiff + Sqr(Result.NNValuesMs[I] - (SumNN / Result.PureNNCount));
    Result.SDNN := Sqrt(SumSqDiff / (Result.PureNNCount - 1));

    MinHR := 999; MaxHR := 0;
    for I := 0 to Result.PureNNCount - 8 do
    begin
      SmoothSum := 0;
      for H := 0 to 7 do SmoothSum := SmoothSum + Result.NNValuesMs[I + H];
      CurHR := 60000.0 / (SmoothSum / 8.0);
      if CurHR < MinHR then MinHR := CurHR;
      if CurHR > MaxHR then MaxHR := CurHR;
    end;
    Result.MinHR := MinHR;
    Result.MaxHR := MaxHR;

    // rMSSD ve pNN50
    SumSqDiff := 0;
    PnnCount := 0;
    for I := 0 to DiffList.Count - 1 do
    begin
      SumSqDiff := SumSqDiff + Sqr(DiffList[I]);
      if Abs(DiffList[I]) > 50.0 then Inc(PnnCount);
    end;
    Result.rMSSD := Sqrt(SumSqDiff / DiffList.Count);
    Result.pNN50 := (PnnCount / DiffList.Count) * 100.0;

    // Triangular Index (7.8125 ms bin)
    FillChar(Hist, SizeOf(Hist), 0);
    MaxBin := 1;
    for I := 0 to Result.PureNNCount - 1 do
    begin
      BinIdx := Trunc((Result.NNValuesMs[I] - 300.0) / (1000.0 / FS_HZ));
      if (BinIdx >= 0) and (BinIdx <= 300) then
      begin
        Inc(Hist[BinIdx]);
        if Hist[BinIdx] > MaxBin then MaxBin := Hist[BinIdx];
      end;
    end;
    Result.TriangularIndex := Result.PureNNCount / MaxBin;

    // 5 dakikalık segmentler (SDANN ve SDNN Index)
    SegMeans := TList<Double>.Create;
    SegStds := TList<Double>.Create;
    try
      CurSeg := 0;
      I := 0;
      while I < Result.PureNNCount do
      begin
        SegIdx := Trunc((Result.NNTimesSec[I] - Result.NNTimesSec[0]) / 300.0);
        if SegIdx > CurSeg then CurSeg := SegIdx;
        SumNN := 0; PnnCount := 0;
        while (I < Result.PureNNCount) and (Trunc((Result.NNTimesSec[I] - Result.NNTimesSec[0]) / 300.0) = CurSeg) do
        begin
          SumNN := SumNN + Result.NNValuesMs[I];
          Inc(PnnCount);
          Inc(I);
        end;
        if PnnCount > 20 then
        begin
          SegMeans.Add(SumNN / PnnCount);
          SumSqDiff := 0;
          for H := I - PnnCount to I - 1 do
            SumSqDiff := SumSqDiff + Sqr(Result.NNValuesMs[H] - (SumNN / PnnCount));
          SegStds.Add(Sqrt(SumSqDiff / (PnnCount - 1)));
        end;
      end;

      if SegMeans.Count > 1 then
      begin
        SumNN := 0;
        for I := 0 to SegMeans.Count - 1 do SumNN := SumNN + SegMeans[I];
        SumSqDiff := 0;
        for I := 0 to SegMeans.Count - 1 do SumSqDiff := SumSqDiff + Sqr(SegMeans[I] - (SumNN / SegMeans.Count));
        Result.SDANN := Sqrt(SumSqDiff / (SegMeans.Count - 1));

        SumNN := 0;
        for I := 0 to SegStds.Count - 1 do SumNN := SumNN + SegStds[I];
        Result.SDNNIndex := SumNN / SegStds.Count;
      end;
    finally
      SegMeans.Free;
      SegStds.Free;
    end;

    // Frekans Alanı (24 Saat, Gündüz, Gece)
    Result.Freq24h := ComputeWindowedPSD(Result.NNTimesSec, Result.NNValuesMs, Result.StartHour, 0);
    Result.FreqDay := ComputeWindowedPSD(Result.NNTimesSec, Result.NNValuesMs, Result.StartHour, 1);
    Result.FreqNight := ComputeWindowedPSD(Result.NNTimesSec, Result.NNValuesMs, Result.StartHour, 2);

    if Result.FreqDay.HF > 0 then
      Result.NightDayHFRatio := Result.FreqNight.HF / Result.FreqDay.HF;

    if (DayNN.Count > 0) and (NightNN.Count > 0) then
    begin
      SumNN := 0; for I := 0 to DayNN.Count - 1 do SumNN := SumNN + DayNN[I];
      SmoothSum := 0; for I := 0 to NightNN.Count - 1 do SmoothSum := SmoothSum + NightNN[I];
      Result.CircadianIndex := (SmoothSum / NightNN.Count) / (SumNN / DayNN.Count);
    end;

    // Saatlik Tablo Oluşturma
    HourlyList := TList<THourlyHrvRow>.Create;
    HNN := TList<Double>.Create;
    HT := TList<Double>.Create;
    HDiff := TList<Double>.Create;
    try
      for H := 0 to 23 do
      begin
        HNN.Clear; HT.Clear; HDiff.Clear;
        for I := 0 to Result.PureNNCount - 1 do
          if (Result.NNTimesSec[I] >= H * 3600.0) and (Result.NNTimesSec[I] < (H + 1) * 3600.0) then
          begin
            if (HNN.Count > 0) and (Abs(Result.NNValuesMs[I] - HNN.Last) < 400.0) then
              HDiff.Add(Result.NNValuesMs[I] - HNN.Last);
            HNN.Add(Result.NNValuesMs[I]);
            HT.Add(Result.NNTimesSec[I]);
          end;

        if HNN.Count > 50 then
        begin
          RealH := Trunc(FMod(Result.StartHour + H, 24.0));
          HRow.RecordHour := H + 1;
          HRow.ClockLabel := Format('%.2d:00-%.2d:00', [RealH, (RealH + 1) mod 24]);
          HRow.NNCount := HNN.Count;

          SumNN := 0;
          for I := 0 to HNN.Count - 1 do SumNN := SumNN + HNN[I];
          HRow.MeanHR := 60000.0 / (SumNN / HNN.Count);

          SumSqDiff := 0;
          for I := 0 to HNN.Count - 1 do SumSqDiff := SumSqDiff + Sqr(HNN[I] - (SumNN / HNN.Count));
          HRow.SDNN := Sqrt(SumSqDiff / (HNN.Count - 1));

          SumSqDiff := 0; PnnCount := 0;
          for I := 0 to HDiff.Count - 1 do
          begin
            SumSqDiff := SumSqDiff + Sqr(HDiff[I]);
            if Abs(HDiff[I]) > 50.0 then Inc(PnnCount);
          end;
          if HDiff.Count > 0 then
          begin
            HRow.rMSSD := Sqrt(SumSqDiff / HDiff.Count);
            HRow.pNN50 := (PnnCount / HDiff.Count) * 100.0;
          end;

          HFreq := ComputeWindowedPSD(HT.ToArray, HNN.ToArray, Result.StartHour, 0);
          HRow.VLF := HFreq.VLF;
          HRow.LF := HFreq.LF;
          HRow.HF := HFreq.HF;
          HRow.LF_HF := HFreq.LF_HF;
          HRow.SympatheticPct := HFreq.SympatheticPct;
          HRow.ParasympatheticPct := HFreq.ParasympatheticPct;
          HourlyList.Add(HRow);
        end;
      end;
      Result.HourlyRows := HourlyList.ToArray;
    finally
      HourlyList.Free; HNN.Free; HT.Free; HDiff.Free;
    end;
  finally
    NNList.Free; TimeList.Free; DiffList.Free;
    PoincX.Free; PoincY.Free; DayNN.Free; NightNN.Free;
  end;
end;

end.
