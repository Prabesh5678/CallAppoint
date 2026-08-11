import uuid
from django.db import models
from accounts.models import User

class PatientMedicalProfile(models.Model):
    BLOOD_GROUP_CHOICES = [
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ]

    SMOKING_CHOICES = [
        ('never', 'Never Smoked'),
        ('former', 'Former Smoker'),
        ('current', 'Current Smoker'),
    ]

    ALCOHOL_CHOICES = [
        ('none', 'Non-drinker'),
        ('occasional', 'Occasional'),
        ('frequent', 'Frequent'),
    ]

    id = models.OneToOneField(
        User,
        primary_key=True,
        on_delete=models.CASCADE,
        db_column='id',
        related_name='medical_profile'
    )
    blood_group = models.CharField(max_length=5, choices=BLOOD_GROUP_CHOICES, null=True, blank=True)

    # Lifestyle (Crucial for Cancer Research)
    smoking_status = models.CharField(max_length=20, choices=SMOKING_CHOICES, default='never')
    alcohol_consumption = models.CharField(max_length=20, choices=ALCOHOL_CHOICES, default='none')
    exercise_frequency = models.CharField(max_length=50, null=True, blank=True)

    # History
    allergies = models.TextField(null=True, blank=True)
    chronic_conditions = models.TextField(null=True, blank=True)
    family_cancer_history = models.BooleanField(default=False)
    family_history_details = models.TextField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'patient_medical_profiles'

    def __str__(self):
        return f"Medical Profile - {self.id.full_name}"

class ClinicalDiagnosis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        db_column='patient_id',
        related_name='diagnoses'
    )
    # The doctor who made this specific diagnosis
    doctor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        db_column='doctor_id',
        related_name='made_diagnoses'
    )

    icd_code = models.CharField(max_length=20, help_text="ICD-10 or ICD-11 code")
    condition_name = models.CharField(max_length=255)
    date_of_diagnosis = models.DateField()

    # Cancer-Specific Staging (TNM System)
    # These are null for non-cancer diagnoses
    tumor_stage = models.CharField(max_length=10, null=True, blank=True, help_text="T (0-4)")
    nodes_stage = models.CharField(max_length=10, null=True, blank=True, help_text="N (0-3)")
    metastasis_stage = models.CharField(max_length=10, null=True, blank=True, help_text="M (0-1)")
    overall_stage = models.CharField(max_length=20, null=True, blank=True, help_text="e.g., Stage IIIA")

    histology = models.TextField(null=True, blank=True, help_text="Cell type/Morphology")
    is_active = models.BooleanField(default=True)
    notes = models.TextField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'clinical_diagnoses'

    def __str__(self):
        return f"{self.condition_name} ({self.icd_code}) - {self.patient.full_name}"

class PatientBiomarker(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        db_column='patient_id',
        related_name='biomarkers'
    )

    name = models.CharField(max_length=100, help_text="e.g., PSA, HER2, Glucose, Hemoglobin")
    value = models.DecimalField(max_digits=10, decimal_places=3)
    unit = models.CharField(max_length=50, help_text="e.g., ng/mL, mg/dL, g/L")

    reference_range = models.CharField(max_length=100, null=True, blank=True, help_text="e.g., 0-4.0")
    recorded_at = models.DateTimeField(help_text="When the lab sample was taken")

    notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'patient_biomarkers'
        ordering = ['-recorded_at']

    def __str__(self):
        return f"{self.name}: {self.value} {self.unit} ({self.patient.full_name})"

class GeneticVariant(models.Model):
    CLINICAL_SIGNIFICANCE_CHOICES = [
        ('pathogenic', 'Pathogenic'),
        ('likely_pathogenic', 'Likely Pathogenic'),
        ('vus', 'Variant of Uncertain Significance (VUS)'),
        ('likely_benign', 'Likely Benign'),
        ('benign', 'Benign'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        db_column='patient_id',
        related_name='genetic_variants'
    )

    gene_name = models.CharField(max_length=50, help_text="e.g., BRCA1, EGFR, TP53")
    variant_description = models.CharField(max_length=255, help_text="e.g., c.5266dupC, p.Glu23Val")

    clinical_significance = models.CharField(
        max_length=30,
        choices=CLINICAL_SIGNIFICANCE_CHOICES,
        default='vus'
    )

    test_date = models.DateField(null=True, blank=True)
    testing_method = models.CharField(max_length=100, null=True, blank=True, help_text="e.g., NGS, PCR")

    notes = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'genetic_variants'

    def __str__(self):
        return f"{self.gene_name} {self.variant_description} - {self.patient.full_name}"
