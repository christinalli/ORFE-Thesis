set more off
set linesize 240
set matsize 800
clear all
capture log close
set maxvar 30000

cd "/Users/christinali/Downloads/ORFE Thesis"
capture mkdir "./Stata"
log using "./Stata/Artist_death.log", replace

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
		
	* Restrict to artists with death years in [1988, 2019]
		drop if missing(artist_death_year)
		drop if artist_death_year < 1988 | artist_death_year > 2019
		
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
	
*** Treatment timing ***
	gen death_year = artist_death_year
	label var death_year "Artist death year"

	gen byte post_death = (auction_year >= death_year) if !missing(auction_year) & !missing(death_year)
	label var post_death "Post-death period"

	gen relative_time = auction_year - death_year
	label var relative_time "Relative year to artist death"
	
*** Difference-in-difference Model ***
    * Regression without any FE 
    eststo ols: reg hammer_price post_death ///
        ib35.ah ib35.location c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, vce(robust)

    * Regression with location FE
    eststo location_fe: reghdfe hammer_price post_death ///
        ib35.ah c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, absorb(location) vce(robust)

    * Regression with location & auction house FE
    eststo location_house_fe: reghdfe hammer_price post_death ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, absorb(location ah) vce(robust)

    * Regression with location, auction house, and year FE
    eststo location_house_year_fe: reghdfe hammer_price post_death ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat i.signed ///
		i.has_provenance i.exhibited i.has_literature i.cont i.genr c.male, ///
		absorb(location ah auction_year) vce(robust)
		
	* Display table
	esttab ols location_fe location_house_fe location_house_year_fe, ///
		label r2 se b(3) se(3) ///
		mtitle("Hammer price" "Hammer price" "Hammer price" "Hammer price") ///
		title("Difference-in-Differences: Artist Death and Hammer Prices") ///
		keep(post_death) ///
		order(post_death)

	* Save table
	esttab ols location_fe location_house_fe location_house_year_fe ///
		using "./Stata/Regressions/death_hammer.tex", replace ///
		label r2 se b(2) se(2) ///
		mtitle("Hammer price" "Hammer price" "Hammer price" "Hammer price") ///
		title("Difference-in-Differences: Artist Death and Hammer Prices") ///
		keep(post_death) ///
		order(post_death)
		
*** Event study model ***
	preserve
	
	* Keep exact event window [-3, 6]
	capture drop rel_year_shift
	keep if relative_time >= -3 & relative_time <= 6
	label var relative_time "Relative year to artist death"

	* Shift so categories are positive:
	* -3,-2,-1,0,1,2,3,4,5,6  ->  1,2,3,4,5,6,7,8,9,10
	gen rel_year_shift = relative_time + 4
	label var rel_year_shift "Shifted relative year"

	* Controls that vary within artist only
	local controls ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ///
		i.signed i.has_provenance i.exhibited i.has_literature

	* Base period is relative_time = -1, i.e. rel_year_shift = 3
	reghdfe hammer_price ///
		ib3.rel_year_shift ///
		`controls', ///
		absorb(location ah auction_year art) ///
		vce(cluster art)

	*** Build dataset of coefficients and CIs ***
	tempfile esresults
	postfile eshandle rel_year beta se lb ub using `esresults', replace

	* relative_time = -3
	lincom 1.rel_year_shift
	post eshandle (-3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = -2
	lincom 2.rel_year_shift
	post eshandle (-2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* omitted reference period: relative_time = -1
	post eshandle (-1) (0) (.) (0) (0)

	* relative_time = 0
	lincom 4.rel_year_shift
	post eshandle (0) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 1
	lincom 5.rel_year_shift
	post eshandle (1) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 2
	lincom 6.rel_year_shift
	post eshandle (2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 3
	lincom 7.rel_year_shift
	post eshandle (3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 4
	lincom 8.rel_year_shift
	post eshandle (4) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 5
	lincom 9.rel_year_shift
	post eshandle (5) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* relative_time = 6
	lincom 10.rel_year_shift
	post eshandle (6) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	postclose eshandle

	use `esresults', clear
	sort rel_year

	*** Graph ***
	twoway ///
		(rcap ub lb rel_year if rel_year != -1, lcolor(blue) lwidth(medthin)) ///
		(scatter beta rel_year if rel_year < 0 & rel_year != -1, ///
			mcolor(green) msymbol(O) msize(medium)) ///
		(scatter beta rel_year if rel_year >= 0, ///
			mcolor(red) msymbol(O) msize(medium)) ///
		(scatter beta rel_year if rel_year == -1, ///
			mcolor(red) msymbol(O) msize(medium)) ///
		, ///
		xline(-1, lcolor(black) lwidth(medium)) ///
		yline(0, lcolor(red) lpattern(dash)) ///
		xlabel(-3(1)6) ///
		xtitle("Relative year") ///
		ytitle("Event study coefficient") ///
		legend(order(2 "Point Estimate" 1 "95% CI") pos(6) ring(0) cols(1)) ///
		graphregion(color(white)) ///
		plotregion(color(white)) ///
		name(estud_death, replace)

	graph export "./Stata/Regressions/estud_death_hammer.pdf", ///
		as(pdf) name(estud_death) replace

	restore
