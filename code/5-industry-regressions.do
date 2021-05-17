cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

use data/intermediate/merged_MetroMSAs_constructionretail_private_post01, clear

//take logs
gen log_avg_annual_pay = ln(avg_annual_pay)
gen log_annual_avg_emplvl = ln(annual_avg_emplvl)
gen log_federal_funding = ln(federal_funding * 1000)
recode log_* (. = 0)

replace avg_annual_pay = avg_annual_pay/1000
label variable avg_annual_pay "Average annual pay of employed workers (thousands 2019$)"
replace annual_avg_emplvl = annual_avg_emplvl / 1000
label variable annual_avg_emplvl "Annual average of total employment (thousands)"
replace federal_funding = federal_funding / 1000
label variable federal_funding "Total federal FFRDC funding received (millions 2019$)"

preserve
keep if industry_code == "23"
save data/intermediate/merged_MetroMSAs_construction_private_post01_scaled, replace
restore

preserve
keep if industry_code == "44-45"
save data/intermediate/merged_MetroMSAs_retail_private_post01_scaled, replace
restore




//construction
use data/intermediate/merged_MetroMSAs_construction_private_post01_scaled, clear

estimates clear
eststo: estpost summarize avg_annual_pay annual_avg_emplvl federal_funding
esttab using output/summarystats_construction.csv, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") label nodepvar replace

encode msacode, gen(msa_factor)

//OLS, construction
reg log_avg_annual_pay log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/reg_construction.doc, replace ctitle("OLS full controls, Average annual pay (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

reg log_annual_avg_emplvl log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/reg_construction.doc, append ctitle("OLS full controls, Average employment (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)


//defense instrument, construction

merge m:1 msacode msatitle using data/intermediate/defense_budget_ratios
recode avg_budget_ratio (. = 0)
drop _merge

merge m:1 year using data/intermediate/total_us_military_spending
keep if _merge == 3
drop _merge

gen defense_funding_instrument = avg_budget_ratio * total_military_spending

reg log_federal_funding i.msa_factor, robust cluster(msa_factor)
predict resid_log_federal_funding, residuals
reg defense_funding_instrument i.msa_factor, robust cluster(msa_factor)
predict resid_defense_funding_instrument, residuals

reg resid_log_federal_funding resid_defense_funding_instrument, robust cluster(msa_factor)
outreg2 using output/defense_first_stage_construction.doc, replace ctitle("With MSA FE") addstat("F stat", e(F))

ivregress 2sls log_avg_annual_pay i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/reg_construction.doc, append ctitle("IV defense instrument, Average annual pay (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
ivregress 2sls log_annual_avg_emplvl i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/reg_construction.doc, append ctitle("IV defense instrument, Average employment (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)




//retail
use data/intermediate/merged_MetroMSAs_retail_private_post01_scaled, clear

estimates clear
eststo: estpost summarize log_avg_annual_pay log_annual_avg_emplvl log_federal_funding
esttab using output/summarystats_retail.csv, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") label nodepvar replace

//OLS, retail
encode msacode, gen(msa_factor)

reg log_avg_annual_pay log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/reg_retail.doc, replace ctitle("OLS full controls, Average annual pay (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)

reg log_annual_avg_emplvl log_federal_funding i.year i.msa_factor i.ffrdc_count, robust cluster(msa_factor)
outreg2 using output/reg_retail.doc, append ctitle("OLS full controls, Average employment (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, Yes, FFRDC count FE, Yes)


//defense instrument, retail

merge m:1 msacode msatitle using data/intermediate/defense_budget_ratios
recode avg_budget_ratio (. = 0)
drop _merge

merge m:1 year using data/intermediate/total_us_military_spending
keep if _merge == 3
drop _merge

gen defense_funding_instrument = avg_budget_ratio * total_military_spending

reg log_federal_funding i.msa_factor, robust cluster(msa_factor)
predict resid_log_federal_funding, residuals
reg defense_funding_instrument i.msa_factor, robust cluster(msa_factor)
predict resid_defense_funding_instrument, residuals

reg resid_log_federal_funding resid_defense_funding_instrument, robust cluster(msa_factor)
outreg2 using output/defense_first_stage_retail.doc, replace ctitle("With MSA FE") addstat("F stat", e(F))

ivregress 2sls log_avg_annual_pay i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/reg_retail.doc, append ctitle("IV defense instrument, Average annual pay (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
ivregress 2sls log_annual_avg_emplvl i.msa_factor (log_federal_funding = defense_funding_instrument i.msa_factor), robust cluster(msa_factor)
outreg2 using output/reg_retail.doc, append ctitle("IV defense instrument, Average employment (log-log)") keep(log_federal_funding) addtext(MSA FE, Yes, Year FE, No, FFRDC count FE, No)
