using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

class RandoCalcV2View extends WatchUi.DataField {

	const do_simulate = 1;

	// -------------------------------------------------------------------------
	// Look up tables.
	// -------------------------------------------------------------------------

	// Distance Offset, Minutes Offset, Minutes/meter for this leg.
	//
	// These units seem a bit strange, but they map onto the native
	// units of the GPS, which are seconds and meters.    Seconds are 
	// a bit unwieldy when the natural unit for the end user is 
	// minutes, so the first step is conversion to minutes. 
	// This is an embedded device, so its better to do any complex math 
	// up front rather than in real time. 
	//
	// Note:   This table looks a little funny because there is bonus
	// time built in due to rounding up the time limits per ACP. 
	// For a 200k and 400k, you get additional time ( 10m and 20m, respectively )

	// Update, Aug 2022 
	const acp_90_lut = [
		[    0,     0, 0.004050000 ],
		[  200,  13.5, 0.003900000 ],
		[  300,  20.0, 0.004200000 ],
		[  400,  27.0, 0.003900000 ],		
		[  600,  40.0, 0.005250000 ],		
		[ 1000,  75.0, 0.004511278 ],		
		[ 0, 0, 0 ] // Mark the end of the list.
		];
		
	const pbp_90_lut = [
		[       0,        0, 0.004000000 ],
		[  217, 14.46667, 0.004000000 ],
		[  306, 20.40000, 0.004277778 ],
		[  360, 24.25000, 0.004282353 ],		
		[  445, 30.31667, 0.004289474 ],		
		[  521, 35.75000, 0.004280899 ],		
		[  610, 42.10000, 0.004313253 ],		
		[  693, 48.06667, 0.004544444 ],		
		[  783, 54.88333, 0.004639535 ],		
		[  869, 61.53333, 0.004611111 ],		
		[  923, 65.68333, 0.004775281 ],		
		[ 1012, 72.76667, 0.004964706 ],		
		[ 1097, 79.80000, 0.005038961 ],		
		[ 1174, 86.26667, 0.004977778 ],		
		[ 1219, 90.00000, 0.004977778 ],		
		[ 0, 0, 0 ]
		];
		
	const pbp_84_lut = [
		[       0,        0, 0.003626728 ],
		[  217, 13.11667, 0.003752809 ],
		[  306, 18.68333, 0.003740741 ],
		[  360, 22.05000, 0.003752941 ],		
		[  445, 27.36667, 0.004000000 ],		
		[  521, 32.43333, 0.004000000 ],		
		[  610, 38.36667, 0.004024096 ],		
		[  693, 43.93333, 0.004122222 ],		
		[  783, 50.11667, 0.004313953 ],		
		[  869, 56.30000, 0.004425926 ],		
		[  923, 60.28333, 0.004617978 ],		
		[ 1012, 67.13333, 0.004717647 ],		
		[ 1097, 73.81667, 0.005025974],		
		[ 1174, 80.26667, 0.004977778 ],		
		[ 1219, 84.00000, 0.004977778 ],		
		[ 0, 0, 0 ] 
		];
		
	const pbp_80_lut = [
		[       0,        0, 0.003525346 ],
		[  217, 12.75000, 0.003539326 ],
		[  306, 18.00000, 0.003518519 ],
		[  360, 21.16667, 0.003752941 ],		
		[  445, 26.48333, 0.003750000 ],		
		[  521, 31.23333, 0.003752809 ],		
		[  610, 36.80000, 0.004024096 ],		
		[  693, 42.36667, 0.003977778 ],		
		[  783, 48.33333, 0.004023256 ],		
		[  869, 54.10000, 0.004222222 ],		
		[  923, 57.90000, 0.004292135 ],		
		[ 1012, 64.26667, 0.004470588 ],		
		[ 1097, 70.60000, 0.004649351 ],		
		[ 1174, 76.56667, 0.004577778 ],		
		[ 1219, 80.00000, 0.004577778 ],		
		[ 0, 0, 0 ] 
		];

	const straight_90_lut = [ // (90*60) / 1200000 
		[ 0, 0, 0.004500000 ],
		[ 0, 0, 0 ] 
		];

	// Table from https://rusa.org/octime_perm.html
	//    0-699 15kph 
	//  700-1299 13.3 kph
	// 1300-1890 12kph 
	// 1900-2499 10kph 
	// 2500+     200km/day 
	const rusa_lut = [
		[       0,         0, 0.00400000000000  ], 
		[  700,  46.66667, 0.004511278195489 ], //  46:40
		[ 1300,  97.75000, 0.000500000000000 ], //  97:45
		[ 1900, 158.33332, 0.000600000000000 ], // 158:20		
		[ 2500, 300.00000, 0.000720000000000 ], // 300:00 	
		[ 0, 0, 0 ] 
		];

	// LEL 125h Rules.   Straight time, 1520km in 125h
	// LEL 2022 Final, with route changes 2022-07-31.   1520km in 125h 
	const lel125_lut = [
		// [ 0, 0, 0.004934210526316 ], // 1520km in 125h
		// [ 0, 0, 0.00487012987013  ], // 1540km in 125h 
		   [ 0, 0, 0.00500000000000  ], // 1540km in 128.333h = 12kph
		   [ 0, 0, 0 ] 
		];

	// These lists will be indexed by the user config settings.
	const luts = [acp_90_lut, pbp_90_lut, pbp_84_lut, pbp_80_lut, straight_90_lut , rusa_lut, lel125_lut ];

	// Displayable table names.
	const method_names = ["ACP90", "PBP90", "PBP84", "PBP80", "RM90" , "RUSA", "LEL128" ];
	
	// -------------------------------------------------------------------------
	// Main Logic 
	// -------------------------------------------------------------------------

    hidden var BankedTime; // Final calulated value.
    hidden var mValueLast; //
    hidden var PreviousBanked;
        
	hidden var table_entry;
	
	hidden var simulated_distance;
	hidden var simulation_counter;
	
	hidden var which_flavor;
	var        method_name;
	
	hidden var verbose; 
	hidden var verbose_cutoff;

	var        lut;
	
	var        trend_data_banked  = new[31];
	hidden var trend_i;
   	hidden var trend_text;

    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();
        BankedTime        = 0.0f;
        PreviousBanked    = 0.0f;
        table_entry       = 0;

		for( var i = 0; i < trend_data_banked.size(); i++ ) {
			trend_data_banked[i]  = 0.0; 
		}

        trend_i           = 0;
   		trend_text        = "";

		verbose           = Application.Properties.getValue("ui_verbose");
		if ( verbose ) { verbose_cutoff = 90.0; }
		else           { verbose_cutoff = 60.0; } 

        which_flavor      = Application.Properties.getValue("method");
        method_name       = method_names[which_flavor];     

		var base_lut      = luts[which_flavor];
		var base_lut_len  = luts[which_flavor].size();

		// From the web example.

		lut = new [ base_lut_len ];

		// Initialize the sub-arrays
		for( var i = 0; i < base_lut_len; i += 1 ) {
    		lut[i] = new [ 3 ];

			
			lut[i][0] = base_lut[i][0] * 1000.0; // km to meters.  API Uses floats.
			lut[i][1] = base_lut[i][1] * 60.0;   // Hours to minutes.
			lut[i][2] = base_lut[i][2]; 

		}

		simulated_distance = 0.0;
		simulation_counter  = 0;

		System.println("Started 0kph");
	    }

	// Generate a monotonic counter that triggers the different 
	// display formats.   Do this with simulated distance. 
	// 30 kph = 30000 m / 3600 s = 8.333 m/s

	// General Plan:
	// Start, 0 kph for 30s
	// 30 kph for 30s 

	function simulate() {
	
		if ( do_simulate != 1 ) { return; } 

		simulation_counter++;
		System.print(".");

		if ( simulation_counter == 240 ) { // Bump to just under 10h surplus
			System.println("Distance = 150km");
			simulated_distance = simulated_distance + 8.38 * 15000;
		}

		if ( simulation_counter == 180 ) { // Bump to just under 90m surplus
			System.println("Distance = 22.5km");
			simulated_distance = simulated_distance + 1.445 * 15000;
		}

		if ( simulation_counter == 130 ) { System.println("Sim 30kph"); } 

		if ( simulation_counter  > 130 ) {
			simulated_distance = simulated_distance + 8.3333;
			return;
		}

		if ( simulation_counter == 90 ) { System.println("Sim 15kph"); } 

		if ( simulation_counter > 90 ) {
			simulated_distance = simulated_distance + 4.15;
			return;
		}

		if ( simulation_counter == 30 ) { System.println("Sim 30kph"); } 
 
		if ( simulation_counter > 30 ) {
			simulated_distance = simulated_distance + 8.3333;
			return;
		}
		
		// Otherwise no movement.   


	}
				
    function compute(info) {

		var distance;
		if ( do_simulate ) {
			simulate();
			distance = simulated_distance;	
		} else {
			distance = info.elapsedDistance;	
		}

   		if ( distance == null || info.elapsedTime == null ) {
   			BankedTime = 0.0f;
   			return;
   			}
    
   		var closetime_mins;
   		var elapsed_mins;

		if ( do_simulate != 1 ) { 
	   		elapsed_mins = (info.elapsedTime * .0000166666 );
		}	
		else { 
	   		elapsed_mins = (info.timerTime * .0000166666 );
		}
   		
		// Figure out which entry.
		// Simplify this to a check for the next one.
		var i = table_entry + 1;
		
		// If the next entry is less than the distance so far
		// and the next entry isn't zero, use that one.
		if ( lut[i][0] != 0 && distance > lut[i][0] ) {
				table_entry = i; // Save state!
				}
		else { i = table_entry; }
		
		// Now we've ID'd the table entry to use.
		var base_mins  = lut[i][1];
		var leg_ridden = distance - lut[i][0];
		var leg_minutes_allowed = leg_ridden * lut[i][2];
		
		closetime_mins = base_mins + leg_minutes_allowed;
		
   		BankedTime = (closetime_mins - elapsed_mins);
   	
		// ---------------------------------------------------------------
		// Trend Calculation for Mario Claussnitzer.
  		// Save the current current banked value. 
		// If you have more banked time than you did 30s ago, its a positive trend.
		{
			var trend_banked  = BankedTime   - trend_data_banked[trend_i];

			// System.print  ("tBanked " + trend_banked + ");

  			if ( trend_banked > 0 ) {
  				trend_text = "+";
  				}
  			else { 
  				trend_text = " ";
  				}

			trend_data_banked[trend_i]  = BankedTime;

			if ( trend_i < 30 ) { trend_i++; }
			else                { trend_i = 0; }
		}

   		return; 
    }
 
	// --------------------------------------------------------------
	// Layout  
	// --------------------------------------------------------------
			
    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var obscurityFlags = DataField.getObscurityFlags();

        // Top left quadrant so we'll use the top left layout
        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));

        // Top right quadrant so we'll use the top right layout
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));

        // Bottom left quadrant so we'll use the bottom left layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));

        // Bottom right quadrant so we'll use the bottom right layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));

        // Use the generic, centered layout
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
            var labelView = View.findDrawableById("label");
            labelView.locY = labelView.locY - 16;
            var valueView = View.findDrawableById("value");
            valueView.locY = valueView.locY + 7;
        }

        View.findDrawableById("label").setText(Rez.Strings.label);
        return true;
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    // Make a local copy of the Calculated value because the 
    // two routines run asyncronously.   This is probably not a hazard,
    // but better to be safe.
    function onUpdate(dc) {
    
    	var inthehole; 
    	var banked;
    	var formatted;
    	
    	// First order of business.  Positive or negative?
    	if ( BankedTime < 0 ) {
    		inthehole = true;
    		banked = BankedTime.abs();
    		formatted = "-";
    		}
    	else {
    		inthehole = false;
    		banked = BankedTime;
    		formatted = "";
    		}
    
    	// System.println(banked);

    	// Format it according to magnitude.
    	// Real world tests show that there are at most 4 usable digits  
		// on a 530, with 10 fields on the screen.
    	
    	// ---------------- Seconds ----------------
    	// XXs 
    	
    	if ( banked < 1.0 ) { // Seconds
    		var seconds = banked * 60.0f;
    		seconds = seconds.toNumber(); // Round to an integer.
    		formatted = seconds.format("%d") + "s";
    		}
    	// ---------------- Up to 60 / 90 Minutes ----------------
    	// XXmSS
    	else if ( banked < verbose_cutoff ) { // Minutes and seconds.
    		var m = banked.toNumber();
    		var s = ( banked - m ) * 60.0f;
    		s = s.toNumber();
    		
    		formatted = m.format("%d") + "m" + s.format("%02d");  	
    		}
    
    	// ---------------- Beyond 60 or 90m ----------------------------
		// The Math is the same for HmMM.M and HHmMM, so do it together.
    	else {
    	    var b_hours = banked * ( 0.0166666666666666666666666f ); // divide by 60
    		
    		var h = b_hours.toNumber();
    		var m = banked - (h * 60.0f); // back to minutes with fractional minutes.

	    	// ---------------- Up to 10 Hours ----------------
	    	// XhYY.Z 
			if ( verbose && banked < 600.0 ) {
	    		formatted = h.format("%d") + "h" +  m.format("%02.1f");  				
				}

	    	// ---------------- Over 10 Hours ----------------
	    	// XXhMM
			else {			
			    // System.println("m +" + m);
		    	m = m.toNumber();
				formatted = h.format("%d") + "h" + m.format("%02d");  				
				}
    		}

		// Add the trend indicator.
		formatted = formatted + trend_text;
		    	    	
    	if ( inthehole ) {
    		if ( getBackgroundColor() == Graphics.COLOR_BLACK ) {
    			View.findDrawableById("Background").setColor(Graphics.COLOR_WHITE);
    			
    			View.findDrawableById("label").setColor(Graphics.COLOR_BLACK);	
 				View.findDrawableById("value").setColor(Graphics.COLOR_BLACK);
    			}
    		else {
 				View.findDrawableById("Background").setColor(Graphics.COLOR_BLACK);

 				View.findDrawableById("label").setColor(Graphics.COLOR_WHITE);
 				View.findDrawableById("value").setColor(Graphics.COLOR_WHITE); 			
    			}

			View.findDrawableById("label").setText("Late " + method_name);
    		}
 		else { 
 			if ( getBackgroundColor() == Graphics.COLOR_BLACK ) {
 				View.findDrawableById("Background").setColor(Graphics.COLOR_BLACK);
 				
 				View.findDrawableById("label").setColor(Graphics.COLOR_WHITE);
 				View.findDrawableById("value").setColor(Graphics.COLOR_WHITE); 			
 				}
 			else {
    			View.findDrawableById("Background").setColor(Graphics.COLOR_WHITE);
    			
    			View.findDrawableById("label").setColor(Graphics.COLOR_BLACK);			
 				View.findDrawableById("value").setColor(Graphics.COLOR_BLACK);
 				}
 				
			View.findDrawableById("label").setText("Banked " + method_name);
 			}   
    
        View.findDrawableById("value").setText(formatted);

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }

}
