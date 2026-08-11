# 2. Our Approach vs. Actual Solution

## The Vision
We wanted a system that was easy for doctors to use but "Gold Mine" for researchers.

## How we approached it
Initially, we thought about just adding more text fields. But we realized that for true research (especially in cancer), we needed a **Categorical System**.

## How we actually solved it
We built a **Layered Architecture** across 5 checkpoints:
1. **Background Layer:** Lifestyle & History.
2. **Clinical Layer:** ICD-10 Coding & TNM Staging.
3. **Temporal Layer:** Time-series Biomarkers.
4. **Precision Layer:** Genomic/Genetic Variants.
5. **Insight Layer:** Analytics Dashboards.

We enforced **Security at the API level** so that doctors only see their own patients, and patients can't fake their own genetic results.
