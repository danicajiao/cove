-- Signal taxonomy seed.
-- verification_method values:
--   'api_lookup'        — automated check against a public API (e.g. USDA NOP)
--   'directory_crossref'— manual or scraped lookup against a public member directory
--   'manual_review'     — staff reviews submitted documents / attestation
--   'kyc'               — automated identity verification via Stripe Identity or Persona
--
-- weight reflects acquisition cost / credibility signal to buyers (1 = baseline, 3 = highest).
-- has_expiry = true means the signal must be re-verified on renewal; the expiry job
-- reads this flag to know which entity_signals rows to monitor.

INSERT INTO catalog.signals (id, code, name, description, verification_method, weight, has_expiry) VALUES

    -- Third-party certifications (highest weight — externally issued, hard to acquire)
    (
        gen_random_uuid(),
        'b_corp',
        'B Corp Certified',
        'Certified by B Lab for meeting rigorous standards of social and environmental performance, accountability, and transparency. Requires comprehensive assessment and renews every three years.',
        'directory_crossref',
        3,
        true
    ),
    (
        gen_random_uuid(),
        'usda_organic',
        'USDA Organic',
        'Certified organic by the USDA National Organic Program. Products meet strict federal standards for organic production and handling. Annual renewal required.',
        'api_lookup',
        3,
        true
    ),
    (
        gen_random_uuid(),
        'fair_trade',
        'Fair Trade Certified',
        'Certified by Fair Trade USA. Workers receive fair wages, work in safe conditions, and farmers receive a price premium invested in their communities. Annual renewal required.',
        'directory_crossref',
        2,
        true
    ),
    (
        gen_random_uuid(),
        'one_pct_planet',
        '1% for the Planet',
        'Member of 1% for the Planet, committing at least 1% of annual sales to vetted environmental nonprofit partners. Annual membership renewal required.',
        'directory_crossref',
        2,
        true
    ),
    (
        gen_random_uuid(),
        'colorado_proud',
        'Colorado Proud',
        'Recognized by the Colorado Department of Agriculture as a Colorado-grown or Colorado-made product. Ongoing program membership verified against the CO Dept of Agriculture directory.',
        'directory_crossref',
        1,
        false
    ),

    -- Staff-reviewed signals
    (
        gen_random_uuid(),
        'living_wage',
        'Living Wage Employer',
        'Pays all workers at or above the MIT Living Wage for their county. Verified through staff-reviewed attestation and payroll documentation.',
        'manual_review',
        2,
        false
    ),

    -- Identity and business verification (baseline trust signals)
    (
        gen_random_uuid(),
        'identity_verified',
        'Identity Verified',
        'Producer identity confirmed via government-issued ID through automated KYC verification. Applies to individual producers operating without a registered business entity.',
        'kyc',
        1,
        false
    ),
    (
        gen_random_uuid(),
        'business_registered',
        'Registered Business',
        'Verified as a registered business entity via D-U-N-S number or state business registry. Applies to LLCs, corporations, and registered sole proprietors.',
        'manual_review',
        1,
        false
    );
