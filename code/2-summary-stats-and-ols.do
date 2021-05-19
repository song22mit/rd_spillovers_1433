cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433


//----------------------------summary stats--------------------------------

use data/intermediate/merged_allMSAs_allind, clear
keep if msatype == "Metro"

//summarize FFRDC count per MSA per year
tab ffrdc year
tab2xl ffrdc year if year >= 1979 & year < 1990 using output/msa_ffrdc_counts_1.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 1990 & year < 2000  using output/msa_ffrdc_counts_2.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 2000 & year < 2010 using output/msa_ffrdc_counts_3.xlsx, replace col(1) row(1)
tab2xl ffrdc year if year >= 2010 using output/msa_ffrdc_counts_4.xlsx, replace col(1) row(1)


//summarize causal and outcome variables
gen has_ffrdc = ffrdc > 0
label define has_ffrdc_values 0 "no FFRDC" 1 "with FFRDC"
label values has_ffrdc has_ffrdc_values

sort year has_ffrdc
replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000
label variable annual_avg_emplvl "Annual average of total employment (thousands)"
replace federal_funding = federal_funding / 1000
label variable federal_funding "Total federal FFRDC funding received (millions 2019$)"

estimates clear
eststo: estpost summarize avg_annual_pay annual_avg_emplvl federal_funding if year >= 2001
esttab using output/summarystats.csv, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") label nodepvar replace

//histograms
drop if year < 2001
encode msacode, gen(msa_factor)

reg avg_annual_pay i.msa_factor i.year, robust
predict resid_avg_annual_pay, residuals
reg annual_avg_emplvl i.msa_factor i.year, robust
predict resid_annual_avg_emplvl, residuals
reg federal_funding i.msa_factor i.year, robust
predict resid_federal_funding, residuals
reg federal_funding i.msa_factor i.year if ffrdc_count > 0, robust
predict resid_federal_funding_hasffrdc, residuals

label variable resid_avg_annual_pay "Avg annual pay of employed workers, resid. by year and MSA (thousands 2019$)"
label variable resid_annual_avg_emplvl "Annual average of total employment, residualized by year and MSA (thousands)"
label variable resid_federal_funding "Total federal FFRDC funding, residualized by year and MSA (millions 2019$)"
label variable resid_federal_funding_hasffrdc "Total federal FFRDC funding, residualized by year and MSA (millions 2019$)"

hist resid_avg_annual_pay, title("Residualized wages across all MSA-years, 2001-2019")
graph export "output/resid_wg.png", as(png) replace
hist resid_annual_avg_emplvl, title("Residualized employment across all MSA-years, 2001-2019")
graph export "output/resid_emp.png", as(png) replace
hist resid_federal_funding, title("Residualized FFRDC funding across all MSA-years," "2001-2019")
graph export "output/resid_fedfunding.png", as(png) replace
hist resid_federal_funding_hasffrdc if ffrdc_count > 0, title("Residualized FFRDC funding across MSA-years" "with at least one FFRDC, 2001-2019")
graph export "output/resid_fedfunding_has_ffrdc.png", as(png) replace

//split summary by year and by FFRDC presence
estimates clear
keep if year == 2019 | year == 2010 | year == 2001

by year has_ffrdc: eststo: estpost summarize avg_annual_pay annual_avg_emplvl federal_funding, listwise
esttab using output/summarystats_by_year_ffrdc.csv, cells("mean(fmt(2)) sd(fmt(2))") label nodepvar replace






//---------------------------OLS----------------------------------------------------


use data/intermediate/merged_MetroMSAs_allind_post01, clear


//take logs
gen log_avg_annual_pay = asinh(avg_annual_pay)
gen log_annual_avg_emplvl = asinh(annual_avg_emplvl)
gen log_federal_funding = asinh(federal_funding * 1000)

//OLS regression 
encode msacode, gen(msa_factor)

reg log_avg_annual_pay log_federal_funding, robust cluster(msa_factor)
outreg2 using output/ols_avg_annual_pay.doc, replace keep(log_federal_funding) addtext(MSA FE, No, Year FE, No, FFRDC count FE, No)
reg log_avg_annual_pay log_federal_funding i.msa_factor, robust cluster(msa_factor)
outreg2 using output/ols_avg_annual_pay.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
reg log_avg_annual_pay log_federal_funding i.year i.msa_factor, robust cluster(msa_factor)
outreg2 using output/ols_avg_annual_pay.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, No)
reg log_avg_annual_pay log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/ols_avg_annual_pay.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

reg log_annual_avg_emplvl log_federal_funding, robust cluster(msa_factor)
outreg2 using output/ols_annual_avg_emplvl.doc, replace keep(log_federal_funding) addtext(MSA FE, No, Year FE, No, FFRDC count FE, No)
reg log_annual_avg_emplvl log_federal_funding i.msa_factor, robust cluster(msa_factor)
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
reg log_annual_avg_emplvl log_federal_funding i.year i.msa_factor, robust cluster(msa_factor)
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, No)
reg log_annual_avg_emplvl log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/ols_annual_avg_emplvl.doc, append keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)
