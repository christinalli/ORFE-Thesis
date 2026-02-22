set more off
set linesize 240
set matsize 800
clear all
capture log close
set maxvar 30000

cd "/Users/christinali/Downloads/ORFE Thesis"
capture mkdir "./Stata"
log using "./Stata/OLS_and_FE_bought_in.log", replace

*** Load data ***
	pq use "./Stata/df_ols.parquet", clear
	
*** Create variables ***
	* Hammer price (outcome variable) 
		drop if missing(bought_in)
		label var has_provenance "Artwork was bought in (unsold)"
		
	* Auction house (independent variable) 
		drop if missing(auction_house_name)
		label var auction_house_name "Auction house"
	
	* Controls 
		* Auction location
		drop if missing(auction_location)
		label var auction_location "Auction location"
		
		* Lot number
		drop if missing(lot_num)
		label var lot_num "Lot number"
		
		* Currency
		drop if missing(currency)
		label var currency "Currency"
		
		* Artwork measurements
		drop if missing(artwork_measurements_width)
		label var artwork_measurements_width "Artwork width (cm)"
		
		drop if missing(artwork_measurements_height)
		label var artwork_measurements_height "Artwork height (cm)"
		
		* Medium
		drop if missing(medium_final)
		label var medium_final "Artwork medium"
		
		* Artist
		drop if missing(artist_name)
		label var artist_name "Artist"
		
		* Artist nationality
		drop if missing(artist_nationality)
		label var artist_nationality "Artist nationality"
		
		* Auction year
		drop if missing(auction_year)
		label var auction_year "Auction year"
		
		* Signed
		drop if missing(signed)
		label var signed "Artwork signed by artist"
		
		* Provenance
		drop if missing(has_provenance)
		label var has_provenance "Artwork has recorded provenance"
		
		* Exhibited
		drop if missing(exhibited)
		label var exhibited "Artwork has recorded exhibition history"
		
		* Literature
		drop if missing(has_literature)
		label var has_literature "Artwork has recorded literature"
		
		* Artist continent
		drop if missing(artist_continent)
		label var artist_continent "Artist continent"
		
		* Artist genre
		drop if missing(artist_genre)
		label var artist_genre "Artist genre"
		
		* Artist gender
		drop if missing(artist_gender)
		label var artist_gender "Artist gender"
		
		gen double male = .
		replace male = 1 if artist_gender == "Male"
		replace male = 0 if artist_gender == "Female"
		label var male "Artist is male"	
		
*** Summary statistics ***
	* Continuous + binary controls (means, SDs, N)
	local contbin_vars bought_in artwork_measurements_width ///
	artwork_measurements_height lot_num auction_year signed has_provenance ///
    exhibited has_literature male

	eststo clear
	estpost summarize `contbin_vars'
	eststo panelA

	esttab panelA using "./Stata/Summary Statistics/continous_variables_bought_in.tex", /// 
		replace ///
		cells("count(fmt(%9.0gc) label(N)) mean(fmt(3) label(Mean)) sd(fmt(3) label(SD))") ///
		label nonumber nomtitles ///
		booktabs fragment

	* Categorical controls
		* Auction house
		preserve

		contract auction_house_name

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gen is_other = (auction_house_name == "Other")
		gsort is_other -_freq

		gen cumpct = sum(pct)

		tempfile out
		file open fh using "./Stata/Summary Statistics/auction_house.tex", write replace

		file write fh "\begin{tabular}{lrrr}" _n
		file write fh "\toprule" _n
		file write fh "Auction house & N & \% & Cum.\ \% \\\\" _n
		file write fh "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = auction_house_name[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh "\bottomrule" _n
		file write fh "\end{tabular}" _n
		file close fh

		restore

		* Auction location
		preserve

		contract auction_location

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gen is_other = (auction_location == "Other")
		gsort is_other -_freq

		gen cumpct = sum(pct)

		tempfile out
		file open fh2 using "./Stata/Summary Statistics/auction_location.tex", write replace

		file write fh2 "\begin{tabular}{lrrr}" _n
		file write fh2 "\toprule" _n
		file write fh2 "Auction location & N & \% & Cum.\ \% \\\\" _n
		file write fh2 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = auction_location[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh2 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh2 "\bottomrule" _n
		file write fh2 "\end{tabular}" _n
		file close fh2

		restore
		
		* Currency
		preserve

		contract currency

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gen is_other = (currency == "Other")
		gsort is_other -_freq

		gen cumpct = sum(pct)

		tempfile out
		file open fh3 using "./Stata/Summary Statistics/currency.tex", write replace

		file write fh3 "\begin{tabular}{lrrr}" _n
		file write fh3 "\toprule" _n
		file write fh3 "Auction currency & N & \% & Cum.\ \% \\\\" _n
		file write fh3 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = currency[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh3 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh3 "\bottomrule" _n
		file write fh3 "\end{tabular}" _n
		file close fh3

		restore

		* Medium
		preserve

		contract medium_final

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gsort -_freq
		gen cumpct = sum(pct)

		file open fh4 using "./Stata/Summary Statistics/medium.tex", write replace

		file write fh4 "\begin{tabular}{lrrr}" _n
		file write fh4 "\toprule" _n
		file write fh4 "Medium & N & \% & Cum.\ \% \\\\" _n
		file write fh4 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = medium_final[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			* escape common LaTeX special chars
			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh4 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh4 "\bottomrule" _n
		file write fh4 "\end{tabular}" _n
		file close fh4

		restore

		* Artist nationality
		preserve

		contract artist_nationality

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gen is_other = (artist_nationality == "Other")
		gsort is_other -_freq

		gen cumpct = sum(pct)

		tempfile out
		file open fh5 using "./Stata/Summary Statistics/artist_nationality.tex", write replace

		file write fh5 "\begin{tabular}{lrrr}" _n
		file write fh5 "\toprule" _n
		file write fh5 "Artist nationality & N & \% & Cum.\ \% \\\\" _n
		file write fh5 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = artist_nationality[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh5 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh5 "\bottomrule" _n
		file write fh5 "\end{tabular}" _n
		file close fh5

		restore

		* Artist continent
		preserve

		contract artist_continent

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gsort -_freq
		gen cumpct = sum(pct)

		file open fh6 using "./Stata/Summary Statistics/continent.tex", write replace

		file write fh6 "\begin{tabular}{lrrr}" _n
		file write fh6 "\toprule" _n
		file write fh6 "Continent & N & \% & Cum.\ \% \\\\" _n
		file write fh6 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = artist_continent[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			* escape common LaTeX special chars
			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh6 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh6 "\bottomrule" _n
		file write fh6 "\end{tabular}" _n
		file close fh6

		restore

		* Artist genre
		preserve

		contract artist_genre

		egen totalN = total(_freq)
		gen pct = 100 * _freq / totalN

		gsort -_freq
		gen cumpct = sum(pct)

		file open fh7 using "./Stata/Summary Statistics/genre.tex", write replace

		file write fh7 "\begin{tabular}{lrrr}" _n
		file write fh7 "\toprule" _n
		file write fh7 "Genre & N & \% & Cum.\ \% \\\\" _n
		file write fh7 "\midrule" _n

		forvalues i = 1/`=_N' {
			local name = artist_genre[`i']
			local N    = string(_freq[`i'], "%12.0fc")
			local p    = string(pct[`i'], "%6.2f")
			local cp   = string(cumpct[`i'], "%6.2f")

			* escape common LaTeX special chars
			local name : subinstr local name "&" "\&", all
			local name : subinstr local name "%" "\%", all
			local name : subinstr local name "_" "\_", all

			file write fh7 "`name' & `N' & `p' & `cp' \\\\" _n
		}

		file write fh7 "\bottomrule" _n
		file write fh7 "\end{tabular}" _n
		file close fh7

		restore
		
*** OLS ***
	* Encode string categoricals -> numeric ids with value labels
	encode auction_house_name, gen(ah)
	encode auction_location, gen(location)
	encode currency, gen(cur)
	encode medium_final, gen(med)
	encode artist_name, gen(art)
	encode artist_nationality, gen(nat)
	encode artist_continent, gen(cont)
	encode artist_genre, gen(genr)

	label var ah "Auction house"
	label var location "Auction location"
	label var cur "Currency"
	label var med "Medium"
	label var art "Artist"
	label var nat "Artist nationality"
	label var cont "Artist continent"
	label var genr "Artist genre"
	
	* Find encoded numeric value that corresponds to the "other" string
	quietly levelsof ah if auction_house_name=="Other", local(base_ah)
	quietly levelsof location if auction_location=="Other", local(base_location)
	quietly levelsof med if medium_final=="other", local(base_med)
	quietly levelsof art if artist_name=="Other", local(base_art)
	quietly levelsof nat if artist_nationality=="Other", local(base_nat)

	display "Base ah = `base_ah'" 
	display "Base location = `base_location'"
	display "Base med = `base_med'"
	display "Base art = `base_art'"
	display "Base nat = `base_nat'"
	
	* OLS  
	eststo ols: reg bought_in ib35.ah ib35.location ///
	c.lot_num i.cur c.artwork_measurements_width c.artwork_measurements_height ///
	ib4.med ib31.art ib1.nat c.auction_year i.signed ///
	i.has_provenance i.exhibited i.has_literature i.cont i.genr c.male
	
	* Location FE
	eststo location_fe: reghdfe bought_in ib35.ah c.lot_num i.cur ///
	c.artwork_measurements_width c.artwork_measurements_height ib4.med ///
	ib31.art ib1.nat c.auction_year i.signed i.has_provenance ///
	i.exhibited i.has_literature i.cont i.genr c.male, absorb(location) ///
    vce(robust)
	
	* Location and auction house FE
	eststo location_house_fe: reghdfe bought_in c.lot_num i.cur ///
	c.artwork_measurements_width c.artwork_measurements_height ib4.med ///
	ib31.art ib1.nat c.auction_year i.signed i.has_provenance ///
	i.exhibited i.has_literature i.cont i.genr c.male, absorb(location ah) ///
    vce(robust)

	* Location, auction house, and year FE
	eststo location_house_year_fe: reghdfe bought_in c.lot_num i.cur ///
	c.artwork_measurements_width c.artwork_measurements_height ib4.med ///
	ib31.art ib1.nat i.signed i.has_provenance i.exhibited i.has_literature ///
	i.cont i.genr c.male, absorb(location ah auction_year) vce(robust)
	
	* Make table without saving and display in results window
	esttab ols location_fe location_house_fe location_house_year_fe, ///
		label r2 se b(3) se(3) ///
		mtitle("Bought in" "Bought in" "Bought in" "Bought in") ///
		title("Determinants of artwork being bought in")

	* Make table and save it
	esttab ols location_fe location_house_fe location_house_year_fe ///
		using "./Stata/Regressions/reg_bought_in.tex", replace ///
		label r2 se b(2) se(2) ///
		mtitle("Bought in" "Bought in" "Bought in" "Bought in") ///
		title("Determinants of artwork being bought in")
