# 5. Future Enhancements & Current Loopholes

## Current Loopholes (Things to watch out for)
1. **Manual Entry Fatigue:** Doctors hate typing. If we don't build a very fast UI with autocompletes, they might just go back to writing text notes.
2. **Data Silos:** This data is only inside CallAppoint. We need to implement FHIR (Fast Healthcare Interoperability Resources) to export it to other hospitals.
3. **Verification:** Currently, any doctor can enter genetic data. In a real hospital, only a Pathologist or Geneticist should be able to do this.

## Future Enhancements
1. **AI Diagnosis Support:** Use the structured data to suggest a diagnosis to the doctor.
2. **Automated PDF Parsing:** Use OCR/AI to read the lab PDFs and automatically fill in the Biomarker table so the doctor doesn't have to type.
3. **Research Export:** A button to export the entire database to a CSV/Excel file for use in tools like R or Python for medical statistics.
