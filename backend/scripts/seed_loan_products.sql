-- Seed standard loan products into sahakari_ms database
INSERT INTO "LoanProducts" ("Id","ProductCode","ProductName","LoanType","InterestRate","InterestType","PenaltyRate","MinAmount","MaxAmount","MinTenureMonths","MaxTenureMonths","ProcessingFeePercent","CollateralRequired","GuarantorRequired","IsActive","IsDeleted","CreatedAt","UpdatedAt")
VALUES
  (gen_random_uuid(),'PL-001','Personal Loan','Personal',14.0,'Diminishing',2,10000,500000,3,60,1.5,false,true,true,false,NOW(),NOW()),
  (gen_random_uuid(),'BL-001','Business Loan','Business',13.0,'Diminishing',2,50000,5000000,6,84,1.0,true,true,true,false,NOW(),NOW()),
  (gen_random_uuid(),'AG-001','Agriculture Loan','Agriculture',11.0,'Diminishing',2,10000,1000000,3,60,1.0,true,false,true,false,NOW(),NOW()),
  (gen_random_uuid(),'HL-001','Home Loan','Housing',12.0,'Diminishing',2,100000,10000000,12,240,0.5,true,true,true,false,NOW(),NOW()),
  (gen_random_uuid(),'MF-001','Microfinance Loan','Personal',15.0,'Flat',3,5000,200000,3,24,2.0,false,true,true,false,NOW(),NOW())
ON CONFLICT DO NOTHING;
