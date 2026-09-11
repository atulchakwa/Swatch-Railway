import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const COLORS = {
  primary: '#0e3a75', secondary: '#1c6abf', success: '#1e8e3e',
  danger: '#d93025', warning: '#f29900', text: '#333333',
  lightGray: '#f5f5f5', border: '#dddddd', white: '#ffffff'
};

const LOGO_IR = path.join(__dirname, '..', '..', 'assets', 'indian_railway.png');

export function createWorkbook() {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Swach Station Cleaning System';
  wb.lastModifiedBy = 'System';
  wb.created = new Date();
  wb.modified = new Date();
  return wb;
}

export function styleHeaderRow(row, color = COLORS.primary) {
  row.font = { bold: true, color: { argb: 'FFFFFFFF' } };
  row.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: color.replace('#', 'FF') } };
}

export function addSummarySheet(workbook, title, data) {
  const sheet = workbook.addWorksheet('Summary', { views: [{ showGridLines: false }] });

  sheet.mergeCells('A1:F2');
  const titleCell = sheet.getCell('A1');
  titleCell.value = title.toUpperCase();
  titleCell.font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
  titleCell.alignment = { vertical: 'middle', horizontal: 'center' };
  titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0E3A75' } };

  let y = 4;

  const addSection = (sectionTitle, keyValueData) => {
    sheet.mergeCells(`A${y}:F${y}`);
    const secHeader = sheet.getCell(`A${y}`);
    secHeader.value = sectionTitle;
    secHeader.font = { name: 'Arial', size: 12, bold: true, color: { argb: 'FFFFFFFF' } };
    secHeader.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1C6ABF' } };
    y++;
    Object.entries(keyValueData).forEach(([key, value]) => {
      sheet.getCell(`B${y}`).value = key;
      sheet.getCell(`B${y}`).font = { bold: true };
      sheet.getCell(`C${y}`).value = value;
      y++;
    });
    y++;
  };

  if (data.meta) addSection('DOCUMENT CONTROL INFORMATION', data.meta);
  if (data.trainInfo) addSection('TRAIN INFORMATION', data.trainInfo);

  if (data.kpi?.metrics) {
    sheet.mergeCells(`A${y}:F${y}`);
    const secHeader = sheet.getCell(`A${y}`);
    secHeader.value = 'KPI SUMMARY';
    secHeader.font = { name: 'Arial', size: 12, bold: true, color: { argb: 'FFFFFFFF' } };
    secHeader.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1C6ABF' } };
    y++;
    sheet.getCell(`B${y}`).value = 'Metric';
    sheet.getCell(`C${y}`).value = 'Result';
    sheet.getCell(`D${y}`).value = 'Status';
    sheet.getRow(y).font = { bold: true };
    sheet.getRow(y).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF5F5F5' } };
    y++;
    data.kpi.metrics.forEach(k => {
      sheet.getCell(`B${y}`).value = k.metric;
      sheet.getCell(`C${y}`).value = k.value;
      const statusCell = sheet.getCell(`D${y}`);
      statusCell.value = k.status;
      y++;
    });
  }

  sheet.getColumn('A').width = 5;
  sheet.getColumn('B').width = 30;
  sheet.getColumn('C').width = 30;
  sheet.getColumn('D').width = 20;
  return sheet;
}

export function addDataSheet(workbook, sheetName, headers, rows) {
  const sheet = workbook.addWorksheet(sheetName);
  sheet.columns = headers.map(h => ({ header: h, key: h, width: 20 }));
  styleHeaderRow(sheet.getRow(1));
  rows.forEach(r => sheet.addRow(r));
  return sheet;
}

export async function createPdf() {
  const doc = new PDFDocument({ margin: 30, size: 'A4' });
  const buffers = [];
  doc.on('data', chunk => buffers.push(chunk));

  const getBuffer = () => new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);
    doc.end();
  });

  return { doc, getBuffer };
}

export function drawPdfHeader(doc, title, subtitle, statusText, isApproved = true) {
  doc.rect(30, 30, 535, 60).fill(COLORS.primary);

  if (fs.existsSync(LOGO_IR)) {
    doc.image(LOGO_IR, 40, 35, { height: 50 });
  }

  doc.fillColor(COLORS.white).font('Helvetica-Bold').fontSize(16)
    .text(title, 95, 45, { width: 285, align: 'center' });
  doc.fontSize(10).font('Helvetica')
    .text(subtitle, 95, 70, { width: 285, align: 'center' });

  doc.rect(390, 35, 105, 50).fill(COLORS.white);
  doc.fillColor(isApproved ? COLORS.success : COLORS.danger)
    .font('Helvetica-Bold').fontSize(8)
    .text('FINAL COMPLIANCE STATUS', 395, 45, { width: 95, align: 'center' });
  doc.fontSize(12).text(statusText, 395, 60, { width: 95, align: 'center' });
  doc.moveDown(2);
}

export function drawPdfSection(doc, title) {
  if (doc.y + 50 > 800) doc.addPage();
  const y = doc.y;
  doc.rect(30, y, 535, 20).fill(COLORS.primary);
  doc.fillColor(COLORS.white).font('Helvetica-Bold').fontSize(10)
    .text(title, 40, y + 5);
  doc.y = y + 25;
}

export function drawPdfTable(doc, headers, rows, colWidths) {
  if (doc.y + 60 > 800) doc.addPage();
  let y = doc.y;

  doc.rect(30, y, 535, 20).fill(COLORS.lightGray);
  doc.fillColor(COLORS.primary).font('Helvetica-Bold').fontSize(8);
  let x = 35;
  headers.forEach((h, i) => { doc.text(h, x, y + 5, { width: colWidths[i] - 5 }); x += colWidths[i]; });
  y += 20;

  doc.font('Helvetica').fontSize(8).fillColor(COLORS.text);
  rows.forEach((row) => {
    const rowH = 25;
    if (y + rowH > 800) { doc.addPage(); y = doc.y; }
    doc.rect(30, y, 535, rowH).stroke(COLORS.border);
    let cx = 35;
    row.forEach((cell, i) => {
      doc.text(String(cell), cx, y + 8, { width: colWidths[i] - 5 });
      cx += colWidths[i];
    });
    y += rowH;
  });
  doc.y = y + 10;
}
