//yeet



use data/intermediate/merged_relevantcounties_allind, clear




gen log_avg_annual_pay = ln(avg_annual_pay)
gen log_dataTotal = ln(dataTotal)
gen log_dataFederal = ln(dataFederal)
encode COUNTY, gen(COUNTY_factor)
save data/intermediate/merged_relevantcounties_allind, replace




use data/intermediate/merged_relevantcounties_allind, clear
reg log_avg_annual_pay log_dataTotal i.year i.COUNTY_factor
reg log_avg_annual_pay log_dataFederal i.year i.COUNTY_factor
reg log_avg_annual_pay log_dataTotal i.year i.COUNTY_factor i.ffrdc_count if ffrdctype == 1
reg log_avg_annual_pay log_dataFederal i.year i.COUNTY_factor i.ffrdc_count

reg annual_avg_emplvl log_dataTotal i.year i.COUNTY_factor
reg annual_avg_emplvl log_dataFederal i.year i.COUNTY_factor
reg annual_avg_emplvl log_dataTotal i.year i.COUNTY_factor i.ffrdc_count if year >= 2001
reg annual_avg_emplvl log_dataFederal i.year i.COUNTY_factor i.ffrdc_count

//plots
use data/intermediate/merged_relevantcounties_allind, clear
egen min_ffrdc_count = min(ffrdc_count), by
keep if ffrdc_count 
drop COUNTY_factor
local n_counties = r(max)
forvalues j = 1(1)`n_counties' {
	
}