//yeet






use data/intermediate/merged_allMSAs_allind, clear

tab ffrdc year if year >= 1979 //TO DO: investigate why the number of MSAs increases between 1979 and 1990
//to do: investigate instances of changes in number of FFRDCs

summarize avg_annual_pay if year == 2019 & ffrdc == 0
summarize avg_annual_pay if year == 2019 & ffrdc > 0
summarize avg_annual_pay if year == 2010 & ffrdc == 0
summarize avg_annual_pay if year == 2010 & ffrdc > 0
summarize avg_annual_pay if year == 2001 & ffrdc == 0
summarize avg_annual_pay if year == 2001 & ffrdc > 0

summarize annual_avg_emplvl if year == 2019 & ffrdc == 0
summarize annual_avg_emplvl if year == 2019 & ffrdc > 0
summarize annual_avg_emplvl if year == 2010 & ffrdc == 0
summarize annual_avg_emplvl if year == 2010 & ffrdc > 0
summarize annual_avg_emplvl if year == 2001 & ffrdc == 0
summarize annual_avg_emplvl if year == 2001 & ffrdc > 0

/*
gen log_avg_annual_pay = ln(avg_annual_pay)
gen log_dataTotal = ln(dataTotal)
gen log_dataFederal = ln(dataFederal)
encode msacode, gen(msa_factor)
save data/intermediate/merged_allMSAs_allind_post01, replace




use data/intermediate/merged_allMSAs_allind_post01, clear
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
*/