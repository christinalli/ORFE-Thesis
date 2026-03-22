set more off
set linesize 240
set matsize 800
clear all
capture log close
set maxvar 30000

cd "/Users/christinali/Downloads/ORFE Thesis"
capture mkdir "./Stata"
log using "./Stata/DID_and_EventStudy_non-European_hammer.log", replace

*** Load data ***
    pq use "./Stata/df_ols.parquet", clear
	
*** Create variables ***
    * Hammer price (outcome variable)
        gen hammer_price = ln(hammer_price_usd_real) if hammer_price_usd_real > 0
        drop if missing(hammer_price)
        label var hammer_price "Natural log of hammer price"

	* Controls	
		* Auction house
        drop if missing(auction_house_name)
        label var auction_house_name "Auction house"

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
        drop if missing(male)
        label var male "Artist is male"
		
	* Clean strings and drop unused variables
		gen strL continent_clean   = trim(lower(artist_continent))
		gen strL nationality_clean = trim(lower(artist_nationality))
		
		drop if artist_nationality == "american"
		drop if artist_continent == "intercontinental"
	
*** Encode string categoricals -> numeric ids with value labels ***
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
	
*** Program to run Europe vs region comparison ***
	capture program drop run_region_did
	program define run_region_did
		syntax , REGION(string) TREATLABEL(string) STUB(string) [DROPAMERICAN]

		preserve

		* Keep Europe plus target region only
		keep if continent_clean == "europe" | continent_clean == "`region'"

		* For North America, drop American nationality
		if "`dropamerican'" != "" {
			drop if nationality_clean == "american"
		}

		* Treatment definition
		gen byte treated = (continent_clean == "`region'")
		label var treated "`treatlabel'"

		* Post-1989
		local expo_year 1989
		gen byte post = (auction_year >= `expo_year') if !missing(auction_year)
		label var post "Post-1989 period"

		gen byte treated_post = treated * post
		label var treated_post "`treatlabel' x Post-1989"

		*** DiD: only location + auction house + year FE ***
		eststo clear

		eststo did_main: reghdfe hammer_price treated treated_post ///
			c.lot_num i.cur c.artwork_measurements_width ///
			c.artwork_measurements_height ib4.med ib31.art ib1.nat ///
			i.signed i.has_provenance i.exhibited i.has_literature ///
			i.genr male, ///
			absorb(location ah auction_year) vce(robust)

		esttab did_main, ///
			label r2 se b(3) se(3) ///
			mtitle("Hammer price") ///
			title("DiD: Europe vs `treatlabel' Around 1989") ///
			keep(treated treated_post) ///
			order(treated treated_post)

		esttab did_main ///
			using "./Stata/Regressions/`stub'_hammer.tex", replace ///
			label r2 se b(2) se(2) ///
			mtitle("Hammer price") ///
			title("DiD: Europe vs `treatlabel' Around 1989") ///
			keep(treated treated_post) ///
			order(treated treated_post)

		*** Event study model ***
		capture drop rel_year rel_year_shift
		gen rel_year = auction_year - `expo_year'

		* Keep only actual years in [-3,6]
		keep if rel_year >= -3 & rel_year <= 6
		label var rel_year "Relative year to 1989"

		* Shift so categories are positive
		gen rel_year_shift = rel_year + 4
		label var rel_year_shift "Shifted relative year"

		* Event-study controls
		local controls ///
			c.lot_num i.cur c.artwork_measurements_width ///
			c.artwork_measurements_height ib4.med ///
			i.signed i.has_provenance i.exhibited i.has_literature

		* Base period is rel_year = -1, which corresponds to rel_year_shift = 3
		reghdfe hammer_price ///
			ib3.rel_year_shift#1.treated ///
			`controls', ///
			absorb(location ah auction_year art) ///
			vce(robust)

		*** Build event-study dataset for graph, normalized to rel_year = -1 ***
		tempfile esresults
		postfile eshandle rel_year beta se lb ub using `esresults', replace

		* rel_year = -3
		lincom 1.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (-3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = -2
		lincom 2.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (-2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* omitted reference period: rel_year = -1
		post eshandle (-1) (0) (.) (0) (0)

		* rel_year = 0
		lincom 4.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (0) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 1
		lincom 5.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (1) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 2
		lincom 6.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 3
		lincom 7.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 4
		lincom 8.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (4) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 5
		lincom 9.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (5) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		* rel_year = 6
		lincom 10.rel_year_shift#1.treated - 3.rel_year_shift#1.treated
		post eshandle (6) (r(estimate)) (r(se)) (r(lb)) (r(ub))

		postclose eshandle

		use `esresults', clear
		sort rel_year

		twoway ///
			(rcap ub lb rel_year if rel_year != -1, lcolor(blue) lwidth(medthin)) ///
			(scatter beta rel_year if rel_year < 0 & rel_year != -1, ///
				mcolor(green) msymbol(O) msize(medium)) ///
			(scatter beta rel_year if rel_year >= 0, ///
				mcolor(red) msymbol(O) msize(medium)) ///
			(scatter beta rel_year if rel_year == -1, ///
				mcolor(red) msymbol(O) msize(medium)) ///
			, ///
			xline(-1, lcolor(black) lpattern(dash) lwidth(medium)) ///
			yline(0, lcolor(red) lpattern(dash)) ///
			xlabel(-3(1)6) ///
			xtitle("Relative year") ///
			ytitle("Event study coefficient") ///
			legend(order(2 "Point Estimate" 1 "95% CI") pos(4) ring(0) cols(1)) ///
			graphregion(color(white)) ///
			plotregion(color(white)) ///
			name(estud_`stub', replace)

		graph export "./Stata/Regressions/estud_`stub'_hammer.pdf", ///
			as(pdf) name(estud_`stub') replace

		* Pre-trends test
		test (1.rel_year_shift#1.treated = 3.rel_year_shift#1.treated) ///
			 (2.rel_year_shift#1.treated = 3.rel_year_shift#1.treated)

		restore
	end

*** Run requested comparisons ***
	run_region_did, region("africa") treatlabel("African Artist") stub("africa")
	run_region_did, region("asia") treatlabel("Asian Artist") stub("asia")
	run_region_did, region("north america") ///
		treatlabel("North American Artist ex-US") stub("northamerica_exus")
	run_region_did, region("oceania") treatlabel("Oceanian Artist") stub("oceania")
	run_region_did, region("south america") treatlabel("South American Artist")  ///
		stub("southamerica")
