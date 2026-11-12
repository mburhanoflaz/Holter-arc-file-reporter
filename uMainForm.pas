unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Math, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Grids, Vcl.FileCtrl, uArcHrvEngine;

type
  TMainForm = class(TForm)
    pnlTop: TPanel;
    btnOpenArc: TButton;
    edtFilePath: TEdit;
    lblStartHour: TLabel;
    edtStartHour: TEdit;
    btnAnalyze: TButton;
    btnExtractFiles: TButton;
    btnSaveRtf: TButton;
    pgMain: TPageControl;
    tsSummary: TTabSheet;
    sgSummary: TStringGrid;
    tsCharts: TTabSheet;
    pbHrvCharts: TPaintBox;
    tsHourly: TTabSheet;
    sgHourly: TStringGrid;
    tsEcg: TTabSheet;
    pnlEcgCtrl: TPanel;
    lblEcgHour: TLabel;
    tbEcgHour: TTrackBar;
    lblEcgTimeInfo: TLabel;
    pbEcg: TPaintBox;
    tsRtfReport: TTabSheet;
    reReport: TRichEdit;
    sbStatus: TStatusBar;
    dlgOpenArc: TOpenDialog;
    dlgSaveRtf: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnOpenArcClick(Sender: TObject);
    procedure btnAnalyzeClick(Sender: TObject);
    procedure btnExtractFilesClick(Sender: TObject);
    procedure btnSaveRtfClick(Sender: TObject);
    procedure pbHrvChartsPaint(Sender: TObject);
    procedure pbEcgPaint(Sender: TObject);
    procedure tbEcgHourChange(Sender: TObject);
  private
    FProcessor: TArcHrvProcessor;
    FReport: THrvReportData;
    FHasData: Boolean;
    procedure PopulateSummaryGrid;
    procedure PopulateHourlyGrid;
    procedure BuildRtfReport;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FProcessor := TArcHrvProcessor.Create;
  FHasData := False;
  DoubleBuffered := True;

  sgSummary.Cells[0, 0] := 'Parametre / Metrik';
  sgSummary.Cells[1, 0] := '24 Saatlik Değer';
  sgSummary.Cells[2, 0] := 'Gündüz (08:00-22:00)';
  sgSummary.Cells[3, 0] := 'Gece (23:00-06:00)';
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FProcessor.Free;
end;

procedure TMainForm.btnOpenArcClick(Sender: TObject);
begin
  if dlgOpenArc.Execute then
  begin
    edtFilePath.Text := dlgOpenArc.FileName;
    Screen.Cursor := crHourGlass;
    try
      FProcessor.LoadFile(dlgOpenArc.FileName);
      btnAnalyze.Enabled := True;
      btnExtractFiles.Enabled := True;
      sbStatus.Panels[0].Text := Format('Yüklendi: %s (%d alt dosya bulundu)',
        [ExtractFileName(dlgOpenArc.FileName), Length(FProcessor.Entries)]);
    finally
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TMainForm.btnAnalyzeClick(Sender: TObject);
var
  DefHour: Double;
begin
  DefHour := StrToFloatDef(edtStartHour.Text, 10.0);
  Screen.Cursor := crHourGlass;
  try
    FReport := FProcessor.Analyze(DefHour);
    FReport.FileName := ExtractFileName(edtFilePath.Text);
    FHasData := True;

    PopulateSummaryGrid;
    PopulateHourlyGrid;
    BuildRtfReport;

    btnSaveRtf.Enabled := True;
    pbHrvCharts.Invalidate;
    pbEcg.Invalidate;

    sbStatus.Panels[0].Text := Format('Analiz tamamlandı | Geçerli Atım: %d | Saf NN: %d | SDNN: %.1f ms | rMSSD: %.1f ms',
      [FReport.ValidBeats, FReport.PureNNCount, FReport.SDNN, FReport.rMSSD]);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.btnExtractFilesClick(Sender: TObject);
var
  DestDir: string;
begin
  DestDir := ExtractFilePath(edtFilePath.Text) + ChangeFileExt(ExtractFileName(edtFilePath.Text), '') + '_icerik';
  if SelectDirectory('Alt dosyaların çıkarılacağı hedef klasörü seçin:', '', DestDir) then
  begin
    FProcessor.ExtractAllEntriesToFolder(DestDir);
    ShowMessage(Format('%d adet alt dosya başarıyla çıkarıldı:'#13#10'%s',
      [Length(FProcessor.Entries), DestDir]));
  end;
end;

procedure TMainForm.btnSaveRtfClick(Sender: TObject);
begin
  dlgSaveRtf.FileName := ChangeFileExt(ExtractFileName(edtFilePath.Text), '_HRV_Raporu.rtf');
  if dlgSaveRtf.Execute then
  begin
    reReport.Lines.SaveToFile(dlgSaveRtf.FileName);
    ShowMessage('RTF klinik raporu kaydedildi: ' + dlgSaveRtf.FileName);
  end;
end;

procedure TMainForm.PopulateSummaryGrid;
  procedure SetRow(R: Integer; const P, V1, V2, V3: string);
  begin
    sgSummary.Cells[0, R] := P;
    sgSummary.Cells[1, R] := V1;
    sgSummary.Cells[2, R] := V2;
    sgSummary.Cells[3, R] := V3;
  end;
begin
  SetRow(1,  'Toplam Ham Kayıt (beats.atr)', IntToStr(FReport.TotalRawRecords), '-', '-');
  SetRow(2,  'Rapor Dışı İşaretçi (Byte34=16)', IntToStr(FReport.ExcludedRecords), '-', '-');
  SetRow(3,  'Geçerli Toplam Atım', IntToStr(FReport.ValidBeats), '-', '-');
  SetRow(4,  'Ektopik Atım Sayısı (Byte34=9)', IntToStr(FReport.EctopicCount), '-', '-');
  SetRow(5,  'Saf NN Aralığı Sayısı', IntToStr(FReport.PureNNCount), '-', '-');
  SetRow(6,  'Ortalama / Min / Maks Kalp Hızı',
    Format('%.0f / %.0f / %.0f bpm', [FReport.MeanHR, FReport.MinHR, FReport.MaxHR]), '-', '-');
  SetRow(7,  'SDNN (ms)', Format('%.1f ms', [FReport.SDNN]), '-', '-');
  SetRow(8,  'SDNN Index (ms)', Format('%.1f ms', [FReport.SDNNIndex]), '-', '-');
  SetRow(9,  'SDANN (ms)', Format('%.1f ms', [FReport.SDANN]), '-', '-');
  SetRow(10, 'rMSSD (ms)', Format('%.1f ms', [FReport.rMSSD]), '-', '-');
  SetRow(11, 'pNN50 (%)', Format('%%%.1f', [FReport.pNN50]), '-', '-');
  SetRow(12, 'HRV Triangular Index', Format('%.1f', [FReport.TriangularIndex]), '-', '-');
  SetRow(13, '--- FREKANS ALANI & OTONOM DENGE ---', '---', '---', '---');
  SetRow(14, 'Analiz Penceresi (5 dk)',
    IntToStr(FReport.Freq24h.WindowCount), IntToStr(FReport.FreqDay.WindowCount), IntToStr(FReport.FreqNight.WindowCount));
  SetRow(15, 'Total Power (ms²)',
    Format('%.1f', [FReport.Freq24h.TotalPower]), Format('%.1f', [FReport.FreqDay.TotalPower]), Format('%.1f', [FReport.FreqNight.TotalPower]));
  SetRow(16, 'VLF Gücü (0.0033-0.04 Hz) (ms²)',
    Format('%.1f', [FReport.Freq24h.VLF]), Format('%.1f', [FReport.FreqDay.VLF]), Format('%.1f', [FReport.FreqNight.VLF]));
  SetRow(17, 'LF Gücü (0.04-0.15 Hz) (ms²)',
    Format('%.1f', [FReport.Freq24h.LF]), Format('%.1f', [FReport.FreqDay.LF]), Format('%.1f', [FReport.FreqNight.LF]));
  SetRow(18, 'HF Gücü (0.15-0.40 Hz) (ms²)',
    Format('%.1f', [FReport.Freq24h.HF]), Format('%.1f', [FReport.FreqDay.HF]), Format('%.1f', [FReport.FreqNight.HF]));
  SetRow(19, 'LF / HF Oranı',
    Format('%.2f', [FReport.Freq24h.LF_HF]), Format('%.2f', [FReport.FreqDay.LF_HF]), Format('%.2f', [FReport.FreqNight.LF_HF]));
  SetRow(20, 'Sempatik Modülasyon (LF nu %)',
    Format('%%%.1f', [FReport.Freq24h.SympatheticPct]), Format('%%%.1f', [FReport.FreqDay.SympatheticPct]), Format('%%%.1f', [FReport.FreqNight.SympatheticPct]));
  SetRow(21, 'Parasempatik Aktivite (HF nu %)',
    Format('%%%.1f', [FReport.Freq24h.ParasympatheticPct]), Format('%%%.1f', [FReport.FreqDay.ParasympatheticPct]), Format('%%%.1f', [FReport.FreqNight.ParasympatheticPct]));
  SetRow(22, 'Gece / Gündüz HF (Vagal) Artış Oranı', Format('%.2fx', [FReport.NightDayHFRatio]), '-', '-');
  SetRow(23, 'Sirkadiyen İndeks (Gece/Gündüz RR)', Format('%.2f', [FReport.CircadianIndex]), '-', '-');
end;

procedure TMainForm.PopulateHourlyGrid;
var
  I: Integer;
  R: THourlyHrvRow;
begin
  sgHourly.RowCount := Length(FReport.HourlyRows) + 1;
  sgHourly.Cells[0, 0] := 'Kayıt Saati';
  sgHourly.Cells[1, 0] := 'Gerçek Saat';
  sgHourly.Cells[2, 0] := 'NN Sayısı';
  sgHourly.Cells[3, 0] := 'Ort. HR';
  sgHourly.Cells[4, 0] := 'SDNN (ms)';
  sgHourly.Cells[5, 0] := 'rMSSD (ms)';
  sgHourly.Cells[6, 0] := 'pNN50 (%)';
  sgHourly.Cells[7, 0] := 'VLF (ms²)';
  sgHourly.Cells[8, 0] := 'LF (ms²)';
  sgHourly.Cells[9, 0] := 'HF (ms²)';
  sgHourly.Cells[10, 0] := 'LF/HF';
  sgHourly.Cells[11, 0] := 'Sempatik %';
  sgHourly.Cells[12, 0] := 'Parasemp. %';

  for I := 0 to High(FReport.HourlyRows) do
  begin
    R := FReport.HourlyRows[I];
    sgHourly.Cells[0, I + 1] := Format('%.2d. Saat', [R.RecordHour]);
    sgHourly.Cells[1, I + 1] := R.ClockLabel;
    sgHourly.Cells[2, I + 1] := IntToStr(R.NNCount);
    sgHourly.Cells[3, I + 1] := Format('%.1f', [R.MeanHR]);
    sgHourly.Cells[4, I + 1] := Format('%.1f', [R.SDNN]);
    sgHourly.Cells[5, I + 1] := Format('%.1f', [R.rMSSD]);
    sgHourly.Cells[6, I + 1] := Format('%.1f', [R.pNN50]);
    sgHourly.Cells[7, I + 1] := Format('%.1f', [R.VLF]);
    sgHourly.Cells[8, I + 1] := Format('%.1f', [R.LF]);
    sgHourly.Cells[9, I + 1] := Format('%.1f', [R.HF]);
    sgHourly.Cells[10, I + 1] := Format('%.2f', [R.LF_HF]);
    sgHourly.Cells[11, I + 1] := Format('%%%.1f', [R.SympatheticPct]);
    sgHourly.Cells[12, I + 1] := Format('%%%.1f', [R.ParasympatheticPct]);
  end;
end;

procedure TMainForm.BuildRtfReport;
  procedure AddBoldLine(const S: string; FontSize: Integer = 11; Color: TColor = clNavy);
  begin
    reReport.SelAttributes.Style := [fsBold];
    reReport.SelAttributes.Size := FontSize;
    reReport.SelAttributes.Color := Color;
    reReport.Lines.Add(S);
    reReport.SelAttributes.Style := [];
    reReport.SelAttributes.Size := 10;
    reReport.SelAttributes.Color := clBlack;
  end;
var
  R: THourlyHrvRow;
begin
  reReport.Lines.BeginUpdate;
  try
    reReport.Clear;
    AddBoldLine('24 SAATLİK HOLTER KALP HIZI DEĞİŞKENLİĞİ (HRV) KLİNİK ANALİZ RAPORU', 13, clNavy);
    reReport.Lines.Add('--------------------------------------------------------------------------------');
    reReport.Lines.Add(Format('Dosya Adı       : %s', [FReport.FileName]));
    reReport.Lines.Add(Format('Cihaz / Format  : Bosram WeCardio 7.0 (.arc) | Başlangıç Saati: %.2d:00', [Trunc(FReport.StartHour)]));
    reReport.Lines.Add(Format('Atım Özeti      : Toplam %d atım (%d Saf NN aralığı, %d Ektopik atım dışlandı)',
      [FReport.ValidBeats, FReport.PureNNCount, FReport.EctopicCount]));
    reReport.Lines.Add('');

    AddBoldLine('1. ZAMAN ALANI (TIME-DOMAIN) PARAMETRELERİ', 11);
    reReport.Lines.Add(Format('  * Ortalama / Min / Maks Kalp Hızı : %.0f / %.0f / %.0f bpm', [FReport.MeanHR, FReport.MinHR, FReport.MaxHR]));
    reReport.Lines.Add(Format('  * SDNN (24 Saat Genel Değişkenlik)  : %.1f ms', [FReport.SDNN]));
    reReport.Lines.Add(Format('  * SDNN Index (5 dk Ort. Std. Sapma) : %.1f ms', [FReport.SDNNIndex]));
    reReport.Lines.Add(Format('  * SDANN (5 dk Ortalamalar Std.Sap.) : %.1f ms', [FReport.SDANN]));
    reReport.Lines.Add(Format('  * rMSSD (Parasempatik / Vagal Tonus): %.1f ms', [FReport.rMSSD]));
    reReport.Lines.Add(Format('  * pNN50 (>50 ms Ardışık Fark Oranı)  : %%%.1f', [FReport.pNN50]));
    reReport.Lines.Add(Format('  * HRV Triangular Index              : %.1f', [FReport.TriangularIndex]));
    reReport.Lines.Add('');

    AddBoldLine('2. FREKANS ALANI (SPEKTRAL) VE SİRKADİYEN OTONOM DENGE', 11);
    reReport.Lines.Add('  Parametre                      24 Saat      Gündüz (08-22)   Gece (23-06)');
    reReport.Lines.Add('  -------------------------------------------------------------------------');
    reReport.Lines.Add(Format('  Total Power (ms²)             %8.1f       %8.1f         %8.1f',
      [FReport.Freq24h.TotalPower, FReport.FreqDay.TotalPower, FReport.FreqNight.TotalPower]));
    reReport.Lines.Add(Format('  VLF Gücü (0.0033-0.04 Hz)     %8.1f       %8.1f         %8.1f',
      [FReport.Freq24h.VLF, FReport.FreqDay.VLF, FReport.FreqNight.VLF]));
    reReport.Lines.Add(Format('  LF Gücü  (0.04-0.15 Hz)       %8.1f       %8.1f         %8.1f',
      [FReport.Freq24h.LF, FReport.FreqDay.LF, FReport.FreqNight.LF]));
    reReport.Lines.Add(Format('  HF Gücü  (0.15-0.40 Hz)       %8.1f       %8.1f         %8.1f',
      [FReport.Freq24h.HF, FReport.FreqDay.HF, FReport.FreqNight.HF]));
    reReport.Lines.Add(Format('  LF / HF Oranı                 %8.2f       %8.2f         %8.2f',
      [FReport.Freq24h.LF_HF, FReport.FreqDay.LF_HF, FReport.FreqNight.LF_HF]));
    reReport.Lines.Add(Format('  Sempatik Modülasyon (LF nu)   %%%7.1f       %%%7.1f         %%%7.1f',
      [FReport.Freq24h.SympatheticPct, FReport.FreqDay.SympatheticPct, FReport.FreqNight.SympatheticPct]));
    reReport.Lines.Add(Format('  Parasempatik Aktivite (HF nu) %%%7.1f       %%%7.1f         %%%7.1f',
      [FReport.Freq24h.ParasympatheticPct, FReport.FreqDay.ParasympatheticPct, FReport.FreqNight.ParasympatheticPct]));
    reReport.Lines.Add('');
    reReport.Lines.Add(Format('  * Gece / Gündüz HF (Vagal) Artış Oranı : %.2fx', [FReport.NightDayHFRatio]));
    reReport.Lines.Add(Format('  * Sirkadiyen İndeks (Gece/Gündüz RR)   : %.2f', [FReport.CircadianIndex]));
    reReport.Lines.Add('');

    AddBoldLine('3. SAATLİK TREND TABLOSU', 11);
    reReport.Lines.Add('  Saat          NN Adet   Ort.HR   SDNN    rMSSD   pNN50    LF/HF   Semp.%  Parasemp.%');
    reReport.Lines.Add('  ------------------------------------------------------------------------------------');
    for R in FReport.HourlyRows do
      reReport.Lines.Add(Format('  %-12s  %7d   %6.1f  %6.1f   %6.1f  %%%5.1f   %6.2f  %%%5.1f     %%%5.1f',
        [R.ClockLabel, R.NNCount, R.MeanHR, R.SDNN, R.rMSSD, R.pNN50, R.LF_HF, R.SympatheticPct, R.ParasympatheticPct]));
  finally
    reReport.Lines.EndUpdate;
  end;
end;

procedure TMainForm.pbHrvChartsPaint(Sender: TObject);
var
  C: TCanvas;
  W, H, HalfW, TopH, BotH, I, Step, X, Y, BarW, SympH: Integer;
  MaxT: Double;
  R: THourlyHrvRow;
begin
  C := pbHrvCharts.Canvas;
  W := pbHrvCharts.Width;
  H := pbHrvCharts.Height;
  C.Brush.Color := clWhite;
  C.FillRect(Rect(0, 0, W, H));

  if not FHasData or (FReport.PureNNCount < 10) then
  begin
    C.TextOut(20, 20, 'Grafikleri görüntülemek için önce bir .arc dosyası yükleyip analizi başlatın.');
    Exit;
  end;

  TopH := (H div 2) - 15;
  BotH := H - TopH - 25;
  HalfW := (W div 2) - 15;

  // 1. ÜST PANEL: 24 Saatlik NN Takogramı
  C.Pen.Color := clSilver;
  C.Rectangle(45, 25, W - 20, TopH);
  C.Font.Style := [fsBold];
  C.TextOut(45, 6, '24 Saatlik NN Takogramı (Ektopik Filtreli, ms)');
  C.Font.Style := [];

  MaxT := FReport.NNTimesSec[High(FReport.NNTimesSec)];
  if MaxT <= 0 then MaxT := 86400;
  Step := Max(1, FReport.PureNNCount div (W - 70));

  C.Pen.Color := $008F5C2B;
  I := 0;
  while I < FReport.PureNNCount do
  begin
    X := 46 + Round((FReport.NNTimesSec[I] / MaxT) * (W - 68));
    Y := TopH - Round(((EnsureRange(FReport.NNValuesMs[I], 300, 1600) - 300) / 1300.0) * (TopH - 30));
    if I = 0 then C.MoveTo(X, Y) else C.LineTo(X, Y);
    Inc(I, Step);
  end;

  // 2. ALT SOL PANEL: Saatlik Sempatik % (Kırmızı) / Parasempatik % (Mavi) Bar Grafiği
  C.Pen.Color := clSilver;
  C.Rectangle(45, TopH + 30, HalfW, H - 25);
  C.Font.Style := [fsBold];
  C.TextOut(45, TopH + 12, 'Saatlik Sempatik % (Alt) vs Parasempatik % (Üst)');
  C.Font.Style := [];

  if Length(FReport.HourlyRows) > 0 then
  begin
    BarW := Max(6, (HalfW - 60) div Length(FReport.HourlyRows) - 3);
    for I := 0 to High(FReport.HourlyRows) do
    begin
      R := FReport.HourlyRows[I];
      X := 52 + I * (BarW + 3);
      SympH := Round((R.SympatheticPct / 100.0) * (BotH - 25));

      // Sempatik (Kırmızı)
      C.Brush.Color := $004F53D9;
      C.FillRect(Rect(X, H - 26 - SympH, X + BarW, H - 26));

      // Parasempatik (Mavi)
      C.Brush.Color := $00DEC05B;
      C.FillRect(Rect(X, TopH + 32, X + BarW, H - 26 - SympH));
    end;
  end;

  // 3. ALT SAĞ PANEL: Poincaré (Lorenz) Diyagramı (NN[n] vs NN[n+1])
  C.Brush.Color := clWhite;
  C.Pen.Color := clSilver;
  C.Rectangle(HalfW + 30, TopH + 30, W - 20, H - 25);
  C.Font.Style := [fsBold];
  C.TextOut(HalfW + 30, TopH + 12, 'Poincaré (Lorenz) Diyagramı (NN[n] vs NN[n+1])');
  C.Font.Style := [];

  Step := Max(1, Length(FReport.PoincareX) div 15000);
  I := 0;
  while I < Length(FReport.PoincareX) do
  begin
    X := HalfW + 35 + Round(((EnsureRange(FReport.PoincareX[I], 300, 1500) - 300) / 1200.0) * (W - HalfW - 60));
    Y := H - 30 - Round(((EnsureRange(FReport.PoincareY[I], 300, 1500) - 300) / 1200.0) * (BotH - 25));
    C.Pixels[X, Y] := $00663300;
    Inc(I, Step);
  end;
end;

procedure TMainForm.tbEcgHourChange(Sender: TObject);
begin
  lblEcgTimeInfo.Caption := Format('%d. Saat (10 sn pencere)', [tbEcgHour.Position]);
  pbEcg.Invalidate;
end;

procedure TMainForm.pbEcgPaint(Sender: TObject);
var
  C: TCanvas;
  W, H, ChH, ChIdx, I, X, Y, MidY: Integer;
  Ch1, Ch2, Ch3, CurCh: TArray<Double>;
begin
  C := pbEcg.Canvas;
  W := pbEcg.Width;
  H := pbEcg.Height;
  C.Brush.Color := clWhite;
  C.FillRect(Rect(0, 0, W, H));

  if Length(FProcessor.Entries) = 0 then Exit;
  if not FProcessor.GetEcgPreview(tbEcgHour.Position * 3600, 10, Ch1, Ch2, Ch3) then Exit;

  ChH := H div 3;
  for ChIdx := 0 to 2 do
  begin
    case ChIdx of
      0: CurCh := Ch1;
      1: CurCh := Ch2;
      2: CurCh := Ch3;
    end;

    MidY := ChIdx * ChH + (ChH div 2);
    C.Pen.Color := $00EAEAEA;
    C.MoveTo(10, MidY);
    C.LineTo(W - 10, MidY);

    C.Font.Style := [fsBold];
    C.TextOut(14, ChIdx * ChH + 8, Format('Kanal %d (%d. Saat - Little-Endian 128 Hz)', [ChIdx + 1, tbEcgHour.Position]));
    C.Font.Style := [];

    C.Pen.Color := $00B4771F;
    for I := 0 to High(CurCh) do
    begin
      X := 10 + Round((I / High(CurCh)) * (W - 20));
      Y := MidY - Round(EnsureRange(CurCh[I], -2.5, 2.5) * (ChH * 0.35));
      if I = 0 then C.MoveTo(X, Y) else C.LineTo(X, Y);
    end;
  end;
end;

end.