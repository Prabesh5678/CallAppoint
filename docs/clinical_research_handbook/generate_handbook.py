import os
import glob
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER
import markdown2

def create_pdf(input_dir, output_file):
    doc = SimpleDocTemplate(output_file, pagesize=letter,
                        rightMargin=72, leftMargin=72,
                        topMargin=72, bottomMargin=18)

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name='Justify', alignment=TA_JUSTIFY))
    styles.add(ParagraphStyle(name='TitlePage', fontSize=24, alignment=TA_CENTER, spaceAfter=30))

    content = []

    # Title Page
    content.append(Spacer(1, 200))
    content.append(Paragraph("CallAppoint", styles['TitlePage']))
    content.append(Paragraph("Clinical Research System Handbook", styles['TitlePage']))
    content.append(Paragraph("A Comprehensive Guide to the Research-Oriented Clinical Database", styles['Normal']))
    content.append(Spacer(1, 50))
    content.append(Paragraph("Generated on: 2026-08-11", styles['Normal']))
    content.append(PageBreak())

    # Get all markdown files in order
    md_files = sorted(glob.glob(os.path.join(input_dir, "*.md")))

    for md_file in md_files:
        with open(md_file, 'r', encoding='utf-8') as f:
            text = f.read()

            # Convert basic markdown to simple HTML that reportlab can handle
            # Note: This is a very simplified conversion for a "monkey-proof" handbook
            lines = text.split('\n')
            for line in lines:
                if line.startswith('# '):
                    content.append(Paragraph(line[2:], styles['Heading1']))
                    content.append(Spacer(1, 12))
                elif line.startswith('## '):
                    content.append(Paragraph(line[3:], styles['Heading2']))
                    content.append(Spacer(1, 10))
                elif line.startswith('### '):
                    content.append(Paragraph(line[4:], styles['Heading3']))
                    content.append(Spacer(1, 8))
                elif line.startswith('- '):
                    content.append(Paragraph("• " + line[2:], styles['Normal']))
                elif line.strip() == '':
                    content.append(Spacer(1, 6))
                else:
                    content.append(Paragraph(line, styles['Normal']))
                    content.append(Spacer(1, 6))

        content.append(PageBreak())

    doc.build(content)
    print(f"Successfully created {output_file}")

if __name__ == "__main__":
    input_directory = "E:/Projects/CallAppoint/docs/clinical_research_handbook"
    output_pdf = "E:/Projects/CallAppoint/docs/Clinical_Research_Handbook.pdf"
    create_pdf(input_directory, output_pdf)
