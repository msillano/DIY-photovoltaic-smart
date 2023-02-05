// Paranetric support for PV on floor, wall
// built using L profiles.

// defaults for my project

// PV panel parameters, defaults for RG-MN-100 (external, mm)
PV_vert = 1050;   // size x
PV_hor  =  530;   // size y (rotate: exchange x,y)
PV_s    = 2.5;    // size z
PV_bolt = true;   // false: no holes - for other PV panels
//
PV_string = 5;    // panels on one row (count)
PV_lines  = 2;    // rows of panels, total panels: PV_string * PV_lines (5*2=10)

// support specs
S_slope = 12;      // angle
S_distance = 700;  // between PV rows 
//
S_large = 1600;    // support distance (implicit defines support number)
S_PVclearance = 2; // intra-panel space for fixing, cable, etc... [mm]
S_leg  = 250;      // support leg size: 0 == none ( e.g. on floor)
S_position = 0.6;  // support leg position (0.5: centered)

// parameters for currents (e.g. wood 25x40)
C_number = 3;     // 2..
C_spess = 25;
C_large = 40;

// parameters for L profile (mm)
L_spess = 1;
L_large = 35;
// note hole: dia 10; 10 + 30 = 40 mm, dimensions
L_r = 5;             // radius: set 0 for no holes
L_s = 40;

// design options
spacer_overlap = 100;  // for spacer junction, default 100, 0 for single row
                     // note: you can cut the extra in front of the first panel row 
// anti manifold const
delta=0.1;
clearance = 3;

// ============================================================= derived
S_base    = PV_vert + 2*S_PVclearance;    // panel base
S_hsize   = S_base  * cos(S_slope);       // panel x projection
S_vsize   = S_base  * sin(S_slope);       // panel y projection
S_v       = S_vsize * S_position + L_large + S_leg;                  // vertical element
S_vert    = S_leg == 0? S_v : (L_r > 0)?floor(S_v / L_s)*L_s: S_v;   // round vertical
S_h       = S_hsize *S_position + 2*spacer_overlap + L_large/2;      // horizontal element
S_hor     = (L_r > 0)?ceil(S_h / L_s) *L_s : S_h;                    // round horizontal
S_spacer  = S_hsize *(1-S_position) + S_distance - L_large - 2*clearance; // spacer element
xfootprint= spacer_overlap + PV_lines * S_hsize + (PV_lines -1) * S_distance ; 
yfootprint= PV_string * PV_hor + (PV_string + 1) * S_PVclearance;     
S_nx      = floor((yfootprint-L_large)/S_large);    
S_n       = S_nx > 1 ? S_nx +1:2;                 // support number
S_extrah  =  (yfootprint - L_large - S_large * (S_n -1))/2;   // extra without support
// note: S_large distance between support (support included)
//  ===S=======S=======S===
//  ---+-------+-------++---
//      S_large S_large  S_extrah


// note nut8: 8, 4, 6.4 (mm) => sizes (from standard metric tables).
module nut8(){
    linear_extrude(height = 6.4) circle(r=8, $fn=6);
}

module bolt8(){
   rotate([0,180,0])union(){
       nut8();
       linear_extrude(height = 6.4+6.4+8) circle(r=4);
       translate([ 0, 0, 6.4+2*L_spess]) nut8();
       } 
}

module holeh(n){
    // used by bar()
    translate([ L_r +L_r + n*L_s, L_large/2, - L_spess])
    linear_extrude(height = 3*L_spess){
      hull() {
       translate([L_s - 4*L_r,0,0]) circle(L_r);
       circle(L_r);
        }
    }
}

module holev(n){
    // used by bar()
 translate([0, L_spess, 0]) rotate(a=[90,0,0])
    holeh(n);   
}

module bar(size){
// builds in 0,0,0 a L profile holed bar of size [mm]
difference() {
  cube([size, L_large, L_large]);
  translate([-delta, L_spess, L_spess]){
     cube([size+2*delta, L_large, L_large]);
     }
 if (L_r >0)      
   for (i=[0:size/L_s]){
     holeh(i);
     holev(i); } 
  }
}

// single lateral supports for a panel row
module asupport(){ 
    bar(S_hor);
// vertical element
    translate([S_hsize*S_position+spacer_overlap, delta, S_vsize * S_position +L_large])   rotate(a=[0, 90, -90])bar(S_vert);
//  panel support element
    translate([spacer_overlap, L_spess, L_large + L_spess])   rotate(a=[-90,-S_slope, 0])bar(S_base);
}

// PV_lines ful support with spacers
module fullsupport(){
    if ( PV_lines > 1)for (i =[1:(PV_lines-1)])translate([ (S_hsize + S_distance) *i ,0,0]) asupport();
    if ( PV_lines > 1)for (j =[1:(PV_lines-1)]){
        translate([ S_hsize * S_position + spacer_overlap + L_large + (S_hsize + S_distance)*(j-1) + clearance ,2,2]) bar(S_spacer);
        // only one bolt indicative per junction (use 2 or 3 bolts)
        translate([ S_hsize * S_position + spacer_overlap + L_large + spacer_overlap/2 +(S_hsize + S_distance)*(j-1) + clearance ,2+6,2+L_large/2])color("blue", 0.5)rotate([-90,0,0]) bolt8();
        translate([ S_hsize * S_position + spacer_overlap + L_large + S_spacer - spacer_overlap +(S_hsize + S_distance)*(j-1) + clearance ,2+6,2+L_large/2])color("blue", 0.5)rotate([-90,0,0]) bolt8();
   }
}
// full metal support structure in place
module fieldsupport(){
    for(i=[1:(S_n-1)]) translate([ 0,L_large + S_large*i,0]) {
       asupport(); 
       fullsupport();
       }
  
}    
// single cuttent
module current(){
    rotate([0,-S_slope,0]) color("BurlyWood")cube([C_large,yfootprint ,C_spess]);
}

// adds required currents over the full structure
module addcurrents(){
 for(i =[0:(PV_lines-1)]){
   for( j= [0:C_number-1]){
     translate([spacer_overlap + (S_hsize + S_distance)*i +j*(S_hsize - C_large)/(C_number -1),-S_extrah + L_large/2 ,L_large+j*(S_vsize - 6)/(C_number -1)])current();
    }
  }
}
// single panel in [0,0], default RG-MN-100,  i.e. 6 bolts fixing
module apanel (){
   translate([spacer_overlap + S_PVclearance,-S_extrah + L_large/2+S_PVclearance,L_large + C_spess]) rotate([0, -S_slope,0])
    union(){
     color("DarkGray", 0.5) cube([PV_vert, PV_hor, PV_s]);
// fixing bolts for RG-MN-100, can be changed  
    if (PV_bolt){        
         color("blue", 0.5)translate([20,20,9]) bolt8();
         color("blue", 0.5)translate([20,PV_hor -20,9]) bolt8();
         if ( PV_vert >  PV_hor) {   // it is vertical
           color("blue", 0.5)translate([PV_vert/2,20,9]) bolt8();
           color("blue", 0.5)translate([PV_vert/2,PV_hor -20,9]) bolt8();
         } else {                    // it is horizontal
           color("blue", 0.5)translate([20,PV_hor/2,9]) bolt8();
           color("blue", 0.5)translate([PV_vert-20,PV_hor/2,9]) bolt8();
        }     
         color("blue", 0.5)translate([PV_vert -20,20,9]) bolt8();
         color("blue", 0.5)translate([PV_vert -20,PV_hor -20,9]) bolt8();
        }
    }   
}
// placing a PV panel over currents, in rigth place
module PVpanel (y,x){           // y: line position (0..4), x: line (0..1)
    translate([x*(S_hsize + S_distance), y*(PV_hor + S_PVclearance),0])apanel();
}

// add all PV panels
module addpanels() {
       for(i = [0:PV_lines-1]) 
          for(j = [0:PV_string-1]) 
               PVpanel (j,i);
}

  echo (str("--------------" ));
  echo (str("Panels ",PV_string, "X", PV_lines,", slope: ",S_slope,"°" ));
  echo (str("Footprint: ",xfootprint,  " x ", yfootprint, " mm" ));
echo ();
  echo (str( S_n * PV_lines, " x supports:"));
  echo (str("   base:   ", S_base, " mm"));
  echo (str("   Hbar:   ", S_hor, " mm"));
  echo (str("   Vbar:   ", S_vert, " mm"));
if( PV_lines > 1){
  echo ();
  echo (str( S_n * (PV_lines -1)  ," x spacer: "));
  echo (str("   length: ", S_spacer, " mm"));
}
  echo ();
  echo (str(C_number * PV_lines," x currents:" ));
  echo (str("   length: ", yfootprint, " mm"));
  echo ();
  echo (str(S_n * (PV_lines -1)*4,"/", S_n * (PV_lines -1)*6,  ," x bolts M8x15 "));
  if (PV_bolt) {
      echo (str(PV_string * PV_lines * 6, " x wood screws M 4x30"));} else {
      echo ();
      echo (str("ganasce:"));
      echo (str("   ",(PV_string -1)* PV_lines * C_number, " x omega"));
      echo (str("   ", PV_lines*C_number * 2, " x Z  "));
  }   
 echo ();
 echo (str("Total L: ", ( S_base + S_hor + S_vert)*S_n * PV_lines + S_spacer* S_n * (PV_lines -1), " mm"));
 
echo(str("----------------"));


// project rendering
   asupport();  
// comment to hide some
   fullsupport();
   fieldsupport();
   addcurrents();
   addpanels();
   