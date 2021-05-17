cd C:\Users\ecsxn\Documents\repo\rd_spillovers_1433

//read in inflation adjustment
import excel data/raw/SeriesReport-20210412000633_ad0ea3.xlsx, cellrange(A12) firstrow clear
ren Year year
drop if year == .
egen dollarvalue = rowtotal(Jan-Dec)
replace dollarvalue = dollarvalue / 12
keep year dollarvalue
replace dollarvalue = dollarvalue / 255.6574
save data/intermediate/inflation_adjustment, replace

//-------------read in and standardize FFRDC data---------
//seed the append loop
clear
set obs 1
gen x=.
save data/intermediate/ffrdcrd_all, replace

//read in and append FFRDC data
forvalues yr = 1979(1)2019 {
    display `yr'
    import delimited data/raw/FFRDC/ffrdcrd`yr'.csv, clear

	tostring(questionnaire_no), format(%02.0f) replace
	tostring(inst_zip), format(%05.0f) replace
	tostring(column status), replace
	
	append using data/intermediate/ffrdcrd_all
	save data/intermediate/ffrdcrd_all, replace
}

//drop seed observation
drop if year == .
drop x
save data/intermediate/ffrdcrd_all, replace


//--------------------crosswalk FFRDC data to county-----------------------------
//import crosswalk file, keep only zips with a unique county, merge to FFRDC data by zip
import excel data/raw/COUNTY_ZIP_122020.xlsx, firstrow clear
duplicates tag ZIP, gen(dup)
drop if dup > 0
drop dup
save data/intermediate/zip_to_county_unique, replace

use data/intermediate/ffrdcrd_all, clear
rename inst_zip ZIP
replace ZIP = substr(ZIP,1,5)
merge m:1 ZIP using data/intermediate/zip_to_county_unique, keepusing(COUNTY)
drop if _merge == 2

//handcode counties where there is no unique county for that zip
replace COUNTY = "25017" if inst_city == "Lexington"
replace COUNTY = "51013" if inst_city == "Arlington"
replace COUNTY = "51510" if inst_city == "Alexandria"
replace COUNTY = "51003" if inst_city == "Charlottesville"
replace COUNTY = "17043" if inst_city == "Argonne"
replace COUNTY = "48453" if inst_city == "Austin"
replace COUNTY = "16019" if inst_city == "Idaho Falls"
replace COUNTY = "35028" if inst_city == "Los Alamos"
replace COUNTY = "06037" if inst_city == "Santa Monica"
replace COUNTY = "06001" if inst_city == "Livermore"
drop if ZIP == "99999"

drop _merge
save data/intermediate/ffrdcrd_all, replace


//---------------------------summarize relevant ffrdc data------------------------

//filter only total funding and federal funding
use data/intermediate/ffrdcrd_all, clear
tab question year
keep if question == "Source"
tab row year
keep if row == "Federal government" | row == "Total"
replace row = "Federal" if row == "Federal government" 
drop questionnaire_no status question
reshape wide data, i(year ffrdctype inst_name_long COUNTY) j(row) string

rename dataFederal federal_funding
rename dataTotal total_funding

//calculate total funding by county by year and number of ffrdcs by county by year
gen ffrdc_count = 1
collapse (sum) total_funding federal_funding ffrdc_count, by(COUNTY year)

save data/intermediate/ffrdcrd_county_summary, replace

//-------------read in and standardize QECW all industry data---------
//seed the append loop
clear
set obs 1
gen x=.
save data/intermediate/qcew_allcounties_allind, replace

//read in and append QCEW data
forvalues yr = 1975(1)2019 {
    display `yr'
	if `yr' <= 2015{
		import delimited "data/raw/QCEW/`yr'.annual 10 Total, all industries.csv", clear
	}
	else {
		import delimited "data/raw/QCEW/`yr'.annual 10 10 Total, all industries.csv", clear
	}
	
	//keep only totals (not by ownership)
	rename area_fips COUNTY
	
	drop oty* //overtime stats, not relevant and not available
	drop lq* //location quotients: only relevant for per-industry stats
	
	tostring(disclosure_code), replace
	
	append using data/intermediate/qcew_allcounties_allind
	save data/intermediate/qcew_allcounties_allind, replace
}

//NOTE: disclosure_code = N means missing data
recode annual* avg_annual_pay total_annual_wages taxable (0 = .) if disclosure_code == "N"
tab agglvl_title
keep if agglvl_title == "County, Total Covered" //not using MSA data, using county data and crosswalking for consistent MSA definition since redraw post census

//drop seed observation
drop if year == .
drop x
save data/intermediate/qcew_allcounties_allind, replace


// --------------- merge qcew with ffrdc data, adjust for inflation-------------------------
use data/intermediate/qcew_allcounties_allind, clear
merge 1:1 year COUNTY using data/intermediate/ffrdcrd_county_summary
drop _merge

merge m:1 year using data/intermediate/inflation_adjustment
drop _merge
foreach dollar_var of varlist total_annual_wages-federal_funding {
    replace `dollar_var' = `dollar_var'/dollarvalue
}

save data/intermediate/merged_allcounties_allind, replace

//--------------crosswalk to and summarize by MSA------------------------
import delimited data/raw/qcew-county-msa-csa-crosswalk-csv.csv, clear
gen COUNTY = string(countycode, "%05.0f")
save data/intermediate/county-to-msa, replace

use data/intermediate/merged_allcounties_allind, clear
merge m:1 COUNTY using data/intermediate/county-to-msa
drop if _merge == 2

//investigate if all FFRDCs are in MSAs
list if ffrdc_count != . & msacode == "" //there is one FFRDC in Barnwell County, SC that is not in a MSA. TO DO: 
drop if msacode == "" //omit that FFRDC

//summarize by MSA
collapse (sum) total_funding federal_funding ffrdc_count annual_avg_estabs_count annual_avg_emplvl total_annual_wages, by(msacode msatitle msatype year)
gen avg_annual_pay = total_annual_wages/annual_avg_emplvl
save data/intermediate/merged_allMSAs_allind, replace

drop if year < 2001 //this has to be done because missing non-academic ffrdcs are now counted as 0 ffrdcs that year

save data/intermediate/merged_allMSAs_allind_post01, replace



//look into only Metro, not Micro
tab ffrdc msatype
list msatitle year if msatype == "Micro" & ffrdc_count > 0 //Alamogordo, NM 2010+, Los Alamos, NM throughout 2001-2019 each with one ffrdc_count

keep if msatype == "Metro"
save data/intermediate/merged_MetroMSAs_allind_post01, replace


