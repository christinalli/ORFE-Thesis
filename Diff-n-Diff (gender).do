set more off
set linesize 240
set matsize 800
clear all
capture log close
set maxvar 30000

cd "/Users/christinali/Downloads/ORFE Thesis"
capture mkdir "./Stata"
log using "./Stata/DID_and_EventStudy_gender_hammer.log", replace

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

        gen byte female = (male == 0) if !missing(male)
        label var female "Artist is female"

*** DiD policy timing: feminist exhibition in 2007 ***
    local expo_year = 2007

    gen byte post = (auction_year >= `expo_year') if !missing(auction_year)
    label var post "Post-2007 period"

    gen byte female_post = female * post
    label var female_post "Female x Post-2007"

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

*** Difference-in-difference Model ***
    * Regression without any FE 
    eststo ols: reg hammer_price female post female_post ///
        ib35.ah ib35.location c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, vce(robust)

    * Regression with location FE
    eststo location_fe: reghdfe hammer_price female post female_post ///
        ib35.ah c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, absorb(location) vce(robust)

    * Regression with location & auction house FE
    eststo location_house_fe: reghdfe hammer_price female post female_post ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat c.auction_year ///
		i.signed i.has_provenance i.exhibited i.has_literature i.cont i.genr ///
		c.male, absorb(location ah) vce(robust)

    * Regression with location, auction house, and year FE
    eststo location_house_year_fe: reghdfe hammer_price female female_post ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib31.art ib1.nat i.signed ///
		i.has_provenance i.exhibited i.has_literature i.cont i.genr c.male, ///
		absorb(location ah auction_year) vce(robust)

    * Display table
    esttab ols location_fe location_house_fe location_house_year_fe, ///
        label r2 se b(3) se(3) ///
        mtitle("Hammer price" "Hammer price" "Hammer price" "Hammer price") ///
        title("DiD: Feminist Exhibition (2007) and Female Artist Prices") ///
        keep(female post female_post) ///
        order(female post female_post)

    * Save table
    esttab ols location_fe location_house_fe location_house_year_fe ///
        using "./Stata/Regressions/gender_hammer.tex", replace ///
        label r2 se b(2) se(2) ///
        mtitle("Hammer price" "Hammer price" "Hammer price" "Hammer price") ///
        title("DiD: Feminist Exhibition (2007) and Female Artist Prices") ///
        keep(female post female_post) ///
        order(female post female_post)

*** Event study model ***
    * Clean variables for event-study (relative to 2007)
	local expo_year 2007

	capture drop rel_year rel_year_binned rel_year_shift
	gen rel_year = auction_year - `expo_year'
	
	drop if rel_year < -3 | rel_year > 6
	label var rel_year "Relative year to 2007 exhibition"

	gen rel_year_shift = rel_year + 4
	label var rel_year_shift "Shifted relative year"
	
	* Only keep controls that vary within artist / lot
	local controls ///
		c.lot_num i.cur c.artwork_measurements_width ///
		c.artwork_measurements_height ib4.med ib1.nat i.signed ///
		i.has_provenance i.exhibited i.has_literature i.cont i.genr

	reghdfe hammer_price ///
		ib3.rel_year_shift#1.female ///
		`controls', ///
		absorb(location ah auction_year art) ///
		vce(robust)

	*** Build event-study dataset for graph, normalized to rel_year = -1 ***
	tempfile esresults
	postfile eshandle rel_year beta se lb ub using `esresults', replace

	* rel_year = -3
	lincom 1.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (-3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = -2
	lincom 2.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (-2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* omitted reference period: rel_year = -1
	post eshandle (-1) (0) (.) (0) (0)

	* rel_year = 0
	lincom 4.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (0) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 1
	lincom 5.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (1) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 2
	lincom 6.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (2) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 3
	lincom 7.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (3) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 4
	lincom 8.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (4) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 5
	lincom 9.rel_year_shift#1.female - 3.rel_year_shift#1.female
	post eshandle (5) (r(estimate)) (r(se)) (r(lb)) (r(ub))

	* rel_year = 6
	lincom 10.rel_year_shift#1.female - 3.rel_year_shift#1.female
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
		legend(order(2 "Point Estimate" 1 "95% CI") pos(3) ring(0) cols(1)) ///
		graphregion(color(white)) ///
		plotregion(color(white)) ///
		name(estud, replace)

	graph export "./Stata/Regressions/estud_gender_hammer.pdf", ///
		as(pdf) name(estud) replace
		
	test (1.rel_year_shift#1.female = 3.rel_year_shift#1.female) ///
	(2.rel_year_shift#1.female = 3.rel_year_shift#1.female)
