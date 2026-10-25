import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {Presentation,PresentationFile} from '@oai/artifact-tool';
const B=path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/,'$1'));
const m=JSON.parse(await fs.readFile(path.join(B,'materials.json'),'utf8'));
const SKILL='C:/Users/lenovo/.codex/plugins/cache/openai-primary-runtime/presentations/26.1020.11127/skills/presentations';
const {applyPresentationChartFont}=await import(pathToFileURL(path.join(SKILL,'container_tools/artifact_tool_utils.mjs')));
const p=Presentation.create({slideSize:{width:1280,height:720}});
const C={ink:'#17344a',muted:'#596773',blue:'#246fb0',orange:'#d95a24',gray:'#888888',rule:'#dce3e8',white:'#ffffff'};
const F='Times New Roman';
const tableOwners=[],chartOwners=[],videoSlots=[],slideIndex=[];
const root=m.root.replaceAll('\\','/');
const src=(s)=>root+'/'+s;
function text(s,str,x,y,w,h,size=25,{bold=false,color=C.ink,align='left'}={}){
 const sh=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
 sh.text=str;sh.text.style={typeface:F,fontSize:size,bold,color,alignment:align,verticalAlignment:'top',insets:0,autoFit:'none',wrap:'square'};
 return sh;
}
function slide(title,notes='',sources=[]){
 const s=p.slides.add();s.background.fill=C.white;
 text(s,title,62,34,1156,68,43,{bold:true});
 text(s,String(p.slides.items.length),1202,676,28,24,17,{color:C.muted,align:'right'});
 s.speakerNotes.text=notes+'\n\nSources\n'+sources.join('\n');
 slideIndex.push({number:p.slides.items.length,title,sources});return s;
}
function footer(s,str){text(s,str,62,646,1128,42,17,{color:C.muted});}
async function image(s,key,x,y,w,h,alt=''){
 const file=m.assets[key]??key;const bytes=await fs.readFile(file);
 return s.images.add({blob:bytes,contentType:'image/png',alt:alt||key,fit:'contain',position:{left:x,top:y,width:w,height:h}});
}
function table(s,values,x,y,w,h,widths,size=24){
 const rows=values.length,cols=values[0].length;
 const t=s.tables.add({rows,columns:cols,left:x,top:y,width:w,height:h,values,columnWidths:widths});
 t.borders.assign({style:'solid',fill:'#dce3e8',width:.6});
 for(let r=0;r<rows;r++)for(let c=0;c<cols;c++){
  const cell=t.getCell(r,c);cell.fill=r===0?C.ink:C.white;
  cell.text.style={typeface:F,fontSize:size,color:r===0?C.white:C.ink,bold:r===0,verticalAlignment:'middle',insets:12,wrap:'square'};
 }
 tableOwners.push(p.slides.items.length);return t;
}
function bar(s,categories,values,x,y,w,h,{yTitle='',max,colors=[C.blue,C.orange],format='0.0'}={}){
 const c=s.charts.add('bar',{position:{left:x,top:y,width:w,height:h},categories,
  series:[{name:yTitle||'Value',values,fill:C.blue,points:values.map((_,idx)=>({idx,fill:colors[idx%colors.length]}))}],
  hasLegend:false,barOptions:{direction:'column',grouping:'clustered',gapWidth:90},
  xAxis:{textStyle:{fontSize:22},line:{fill:C.rule,width:1},majorGridlines:null},
  yAxis:{min:0,...(max?{max}:{}),title:{text:yTitle,textStyle:{fontSize:22}},textStyle:{fontSize:20},numberFormatCode:format,majorGridlines:{fill:C.rule,width:.6}},
  dataLabels:{showValue:true,position:'outEnd',numberFormatCode:format,textStyle:{fontSize:24,bold:true}},
  chartFill:C.white,chartLine:{fill:'none',width:0},plotAreaFill:C.white,plotAreaLine:{fill:'none',width:0}});
 applyPresentationChartFont(c,{fontFamily:F});chartOwners.push(p.slides.items.length);return c;
}
function scatter(s,series,x,y,w,h,{xTitle,yTitle,xmin,xmax,ymin,ymax}){
 const c=s.charts.add('scatter',{position:{left:x,top:y,width:w,height:h},
  series:series.map((r,i)=>({...r,line:{fill:[C.blue,C.orange,C.gray][i],width:i===2?1.3:2.5,style:i===2?'dashed':'solid'},marker:{symbol:'none'}})),
  scatterOptions:{style:'line'},hasLegend:true,legend:{position:'bottom',overlay:false,textStyle:{fontSize:19}},
  xAxis:{title:{text:xTitle,textStyle:{fontSize:22}},min:xmin,max:xmax,textStyle:{fontSize:19},numberFormatCode:'0.##',majorGridlines:{fill:C.rule,width:.5}},
  yAxis:{title:{text:yTitle,textStyle:{fontSize:22}},min:ymin,max:ymax,textStyle:{fontSize:19},numberFormatCode:'0.##',majorGridlines:{fill:C.rule,width:.5}},
  chartFill:C.white,chartLine:{fill:'none',width:0},plotAreaFill:C.white,plotAreaLine:{fill:'none',width:0}});
 applyPresentationChartFont(c,{fontFamily:F});chartOwners.push(p.slides.items.length);return c;
}
async function movie(s,key,x,y,w,h){
 const v=m.videos.find(v=>v.key===key);await image(s,v.poster,x,y,w,h,'VIDEO_SLOT:'+key);
 videoSlots.push({slide:p.slides.items.length,key,path:v.path,poster:v.poster,x,y,w,h});
}
function paragraphs(s,items,x,y,w,size=26,gap=105){items.forEach((t,i)=>text(s,t,x,y+i*gap,w,gap-12,size));}
const e=m.europa.runs,cw=m.cold_warm,fr=m.frozen;

// 1
{
 const s=slide('Melt migration through ice',
  'Research discussion based on the simulations and audits in this chat. The corrected shared S3 solver is the principal baseline. The deck distinguishes completed trajectories, frozen-flow controls, discrete budget reconstructions, and superseded runs with a known pressure-reference bias. Numerical states remain unchanged. All reported units retain their original geometry. Speaker notes include the methods and provenance needed to interpret each result.',
  [src('docs/CENTERED_WATER_S3_SETUP.md'),src('docs/CENTERED_WARM_COLD_CONDUCTION.md'),src('docs/EUROPA_MIGRATION_SIMPLE_EXPLANATION.md')]);
 text(s,'Tests with the shared S3 method',66,200,1100,80,52,{bold:true});
 text(s,'Europa impact melt and closed Cartesian water bodies',66,318,1080,80,32);
 text(s,'Saved results, transport mechanisms, and limits',66,427,1080,70,29,{color:C.muted});
 text(s,'25 October 2026',66,586,1000,40,24,{color:C.muted});
}
// 2
{
 const s=slide('Tests covered in this presentation',
  'The main sequence includes all substantive test families discussed in the chat. Short smoke runs and the interrupted 10,000-year Europa trial appear in the appendix rather than as independent physical predictions. Early tests based on the legacy simple-test parent predate the correct S3 reference forcing; their conservation and boundary checks remain numerical observations, but their migration trajectories are superseded. No Titan simulation result was generated or verified in this sequence.',
  [src('model_and_dependencies/S3_CASE_SWITCH_README.md'),src('docs/FLAT_AND_CENTERED_WATER_VIDEOS.md'),src('docs/CENTERED_COLD_BOTTOM_S3.md')]);
 table(s,[['Test family','Purpose','Reported extent'],['Porosity wave','Shared-method benchmark','800 yr run'],['Europa, two kc values','Delivery and refreezing','Until 0.5% shell melt remains'],['Flat and centered water','Effect of lateral geometry','8.893 yr comparison'],['Warm and cold centered bodies','Thermal and mechanical effects','Both 100 yr'],['Frozen flows and budget controls','Identify transport terms','Identical-state and local tests']],62,130,1156,451,[340,430,386],23);
 footer(s,'Appendix: boundary checks, reference-pressure correction, reproducibility, and interrupted setup runs.');
}
// 3
{
 const s=slide('The numerical method and boundary conditions',
  'The common numerical block computes temperature/compositional buoyancy, Stokes flow with compaction, Darcy flux from the solved pressure-valued head, explicit enthalpy advection and conduction, and phase recovery. The current centered cold copy has a byte-identical core flow/heat/phase block and common numerical helpers relative to the warm copy. The source changes only initialization and read-only accounting. Pressure head P = p_water + rho_water*g*z must use a consistent reference force. The shared correction fsVec = fsVec + (Pi_5 + Ra) is enabled. Actual face conductivity controls the diffusion time-step bound. Wave and Europa parameter choices remain different despite the common equations. An impermeable wall fixes normal material flux, while boundary phi/enthalpy can evolve. The Europa internal delivery plane z=0 is distinct from its sealed external base z=-2 km.',
  [src('docs/CENTERED_WATER_S3_SETUP.md'),src('docs/CENTERED_COLD_BOTTOM_S3.diff'),src('model_and_dependencies/S3_CASE_SWITCH_README.md')]);
 table(s,[['Setting','Wave','Europa / centered tests'],['Permeability law','kc phi^2','kc phi^3'],['Coordinates','Cartesian','Cylindrical / Cartesian'],['Material walls','Closed, free slip','Closed, free slip'],['Thermal walls','Insulated','Cold Europa surface / insulated box']],62,135,1156,320,[350,330,476],24);
 text(s,'Liquid flux = phi v_s + q',68,495,1100,55,34,{bold:true});
 text(s,'The solved pressure head determines q. Wet material can also move with v_s.',68,565,1100,55,26);
 footer(s,'The wave benchmark uses a nonzero porosity background. It does not by itself test invasion of exactly dry ice.');
}
// 4
{
 const s=slide('Porosity wave benchmark',
  'The corrected long S3 run completed 800 years in 2464 updates with the original CSV realization, kc=5.6e-11 m2, Cartesian 256 x 1024 grid, phi background 0.001, and exponent 2. The displayed live-comparison snapshot is at 575.462353 years (step 1772), not the 800-year endpoint. Its reported numerical peak speed is 7.15162087 m/year against 7.1946405 m/year theoretical, a -0.59794% difference. The reported amplitude change is -0.699878%. The analytic curve translates the supplied initial wave using an interpolant for the reference field only. The simulation snapshots remain unchanged. Long closed-domain behavior and a nonzero background distinguish this benchmark from an initially dry interface. The accompanying movie re-encodes the original saved numerical AVI frames, without synthesizing numerical states.',
  [src('Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/live_comparison/summary.txt'),src('Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/COMPLETE.txt'),src('Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/RUN_SETTINGS.txt')]);
 await image(s,'wave',62,133,780,458);
 text(s,'Peak speed',895,148,315,40,27,{bold:true});
 text(s,'7.152 m/yr',895,202,315,60,41,{bold:true,color:C.blue});
 text(s,'Theory: 7.195 m/yr\nDifference: -0.60%',895,279,315,90,25);
 text(s,'Comparison at 575.46 yr\nFull run reached 800 yr',895,429,315,100,24,{color:C.muted});
 footer(s,'Analytic reference and numerical fields shown at the actual comparison snapshot.');
}
// 5
{
 const s=slide('Porosity wave movie',
  'This movie contains the 157 frames already saved by the completed numerical S3 run, re-encoded from s3_melt_temperature.avi to MP4. Frame repetition preserves the source playback duration to within one encoded frame. The plot timestamps are the recorded simulation times. It contains no interpolated numerical trajectory or generated intermediate fields.',
  [src('Output/Jake_2D_minimal_800_years_actual_kappa_head_reference/s3_melt_temperature.avi')]);
 await movie(s,'wave',125,130,1030,480);footer(s,'0 to 800 simulated years. Click the movie during Slide Show to play.');
}
// 6
{
 const s=slide('Europa permeability comparison',
  'Both completed impact_melt_europa trajectories use the same archived corrected solver, cylindrical r-z mesh, input impact state, material laws, sealed external base and cubic porosity-permeability law. The lower region z<0 starts dry at 273 K. Delivery is cumulative net downward liquid transfer across the internal z=0 plane, not every downward crossing. The times shown are the first actual diagnostic updates reaching 50% of the initial shell melt inventory as net delivery. They are 82.5246904 yr and 623.5251 yr, with no time interpolation. This like-volume milestone is more informative than comparing velocities at two different evolved states. The kc mobility ratio is 1e8, while the coupled half-delivery-time ratio is about 7.56. Pressure, deformation, porosity, and thermal evolution adjust together.',
  [src('Output/Europa_permeability_comparison_20261024/comparison.json'),src('model_and_dependencies/EUROPA_RESEARCH_OUTPUTS.md')]);
 const high=e.high.milestones.delivery_50pct_of_initial.time_years,low=e.low.milestones.delivery_50pct_of_initial.time_years;
 bar(s,['kc = 1.85e-8','kc = 1.85e-16'],[high,low],62,145,690,445,{yTitle:'Years to deliver 50% of initial shell melt',max:750});
 text(s,(low/high).toFixed(2)+' times',825,187,370,75,49,{bold:true,color:C.orange});
 text(s,'longer at low kc',825,272,370,50,29);
 text(s,'Same initial state\nSame cubic law\nNet transfer across z = 0',825,383,370,155,25);
 footer(s,'The mobility ratio alone does not predict the coupled migration-speed ratio.');
}
// 7
{
 const s=slide('Europa endpoint liquid budgets',
  'Stop condition: integrated liquid volume in all z>=0 cells reaches 0.005 of its actual initialized inventory. This combines delivery and net refreezing; it is not a condition that every shell cell reaches phirem. Initial shell liquid is 31.7803512837 km3. High kc: 3587.4578975 yr, 50697 steps, net delivery 30.3298847327 km3, signed net shell refreezing 1.2915689430 km3, remaining shell liquid 0.1588976080 km3. Low kc: 47138.2460495 yr, 14406 steps, net delivery 25.973671383 km3, net shell refreezing 5.647945941 km3, remaining 0.158733960 km3. The budget includes a shared zero-time phase-equilibration reduction of 0.3672852028 km3. Refreezing means freezing minus new melting in the discrete budget. It does not count gross freeze-remelt cycles or uniquely tagged impact water.',
  [src('Output/Europa_permeability_comparison_20261024/comparison.json'),src('docs/EUROPA_REPRODUCIBILITY.md')]);
 table(s,[['Quantity','kc = 1.85e-8','kc = 1.85e-16'],['Depletion time [yr]','3,587.46','47,138.25'],['Net delivery [km3]','30.330','25.974'],['Net shell refreezing [km3]','1.292','5.648'],['Shell liquid remaining [km3]','0.15890','0.15873']],62,147,1156,360,[540,308,308],27);
 text(s,'Higher permeability delivers more water before the shell inventory is depleted.',70,548,1130,75,29,{bold:true});
 footer(s,'Both net-refreezing values include the common 0.3673 km3 initial phase-equilibration adjustment.');
}
// 8
{
 const s=slide('Europa movies',
  'Both movies use actual saved Eulerian fields, repeated between saved states. High kc contains 388 saved states and ends at 3587.4579 yr. Low kc contains 1168 saved states and ends at 47138.2460 yr. Variable playback speed and distinct end times mean these are not synchronized equal-time animations. Their annotations retain their own actual simulation time. The external base is z=-2 km and z=0 is the internal delivery plane. The original videos and decoded-frame checks are preserved in each run/research_video folder.',
  [src('docs/EUROPA_VIDEO.md'),src('Output/Europa_kc_1.850e-08_until_depleted_20261023_195524/research_video/video_verification.json'),src('Output/Europa_kc_1.850e-16_until_depleted_20261024_085440/research_video/video_verification.json')]);
 text(s,'High kc: 1.85e-8 m2',66,147,548,50,29,{bold:true});text(s,'Low kc: 1.85e-16 m2',666,147,548,50,29,{bold:true});
 await movie(s,'europa_high',64,218,552,311);await movie(s,'europa_low',664,218,552,311);
 text(s,'Ends at 3,587 years',66,553,548,40,26);text(s,'Ends at 47,138 years',666,553,548,40,26);
 footer(s,'Click each movie in Slide Show. The two playback clocks represent different physical times.');
}
// 9
{
 const s=slide('First wetting with zero Darcy permeability',
  'The selected initially dry Europa cell is r=100 m, z=6250 m. All incident harmonic face mobilities and relative Darcy fluxes are zero. At its upper face, the high-kc initial solid speed is 13.768143 m/year downward and the upstream phi is 0.25. With annular face area 125663.706 m2, carried liquid Q=0.25*13.768143*125663.706=432538.975 m3/year. The actual first dt is 0.00327783285 yr, producing 1417.79046 m3 and phi=0.000112824180155. Conduction and Darcy enthalpy contributions are zero for this event. Equal solid volume leaves, so cell volume remains fixed. The low-kc initial carried Q is 422665.903 m3/year, only 2.34% different. This first wetting identifies movement of wet material and upwind transport into a fixed cell, not a pore-nucleation law for a stationary dry parcel.',
  [src('docs/EUROPA_FACE_FLUX_PROOF.md'),src('Output/Europa_face_flux_proof_20261024/face_flux_proof.json')]);
 await image(s,'dry_cell',60,127,850,475);
 text(s,'q = 0',950,155,270,60,43,{bold:true});
 text(s,'Carried liquid still enters',950,237,270,100,27,{bold:true});
 text(s,'Q = 432,539 m3/yr\n\nSaved gain: 1,417.79 m3',950,365,270,160,24);
 footer(s,'A fixed grid cell becoming wet does not demonstrate formation of pores in the original material parcel.');
}
// 10
{
 const s=slide('Dilation changes porosity within wet material',
  'In source-free incompressible two-phase flow, div(v_s+q)=0, so div(v_s)=-div(q). For solid mass conservation with negligible phase change, D_s(phi)/Dt=(1-phi)*div(v_s). Positive solid divergence can increase porosity in an already wet region. The selected initial Europa cell r=1.7 km,z=8.15 km starts at phi=0.4375. Its high-kc solid divergence is 19.1262559/year and dilation porosity rate 10.7585189/year. Low kc gives 3.34355098e-7/year and 1.88074743e-7/year. Actual adaptive dt differ slightly: 0.00327783285 vs 0.00332803149 yr. Dilation accounts for 88.915% of the selected high-kc local Eulerian phi increment, not 88.915% of total migration. Co-location of q convergence and dilation follows the coupled constraint and is not independent causal proof. This example supports dilation in wet material while the dry-cell example identifies a different initial-wetting process.',
  [src('docs/EUROPA_DILATION_EVIDENCE.md'),src('Output/Europa_dilation_evidence_20261024/dilation_evidence.json'),'https://aspect-documentation.readthedocs.io/en/stable/user/methods/melt-transport.html']);
 await image(s,'dilation',64,125,1152,450);
 text(s,'D_s(phi)/Dt = (1 - phi) div(v_s)',78,580,1110,48,29,{bold:true});
 footer(s,'Selected local budget. The dilation fraction does not measure the fraction of total delivery caused by dilation.');
}
// 11
{
 const s=slide('Changing kc at the same melt shape',
  'Four frozen-flow solves use corrected S3 equations. Initial high/low cases have identical H,phi,T,geometry,gravity,rheology and walls. The later pair both use the actual high-kc one-year shape. Only kc changes and pressure/velocity are recomputed; time and enthalpy do not advance. The later low-kc control is not a low-kc trajectory evolved to one year. Across z=4 km, downward-positive integrated rates at that same shape are high: carried -17.941467079, Darcy +21.887463382, net +3.945996303 million m3/year/m; low: carried +0.406986862, Darcy +0.000000351411, net +0.406987213. Net ratio is 9.695627. Upward carried liquid partly cancels high-kc downward Darcy flow. Initially, carried Q differs by only 0.125%, and the selected dry-face solid speed is 57.9197 versus 58.1651 m/year, so initially faster bulk advection is not the explanation.',
  [src('docs/CENTERED_WATER_PERMEABILITY_MECHANISM.md'),src('Output/centered_water_permeability_proof_20261024_215923/permeability_proof.json')]);
 table(s,[['Downward Q [million m3/yr/m]','High kc','Low kc'],['Carried with solid','-17.941','+0.407'],['Darcy segregation','+21.887','+0.000000351'],['Net liquid transfer','+3.946','+0.407']],62,153,855,310,[465,195,195],24);
 text(s,'9.70x',969,178,230,80,55,{bold:true,color:C.orange});
 text(s,'net transfer\nat the same shape',969,280,235,110,26);
 text(s,'High-kc Darcy flow outweighs the opposing carried contribution.',70,516,1130,65,30,{bold:true});
 footer(s,'Frozen-state mechanism control. This ratio is neither a completion-time ratio nor a measured dry-front speed.');
}
// 12
{
 const s=slide('Flat layer and centered water body',
  'The corrected Cartesian comparison uses the same S3 solver, closed/insulated walls, x=0-20 km, z=-2 to10 km, 100x120 cells, 273 K initially, kc=1.85e-8 and exponent3. The flat case sets phi=1 above z=4 km across the full width, with no imposed lateral perturbation. It remains nearly hydrostatic: max absolute phi change 1.240337e-9 through8.893483yr, max formal solid component3.46784e-7m/year andmaxq1.4808e-9. The centered body occupies x5-15km abovez4km and introduces lateral density contrast and circulation. This is not a volume-controlled geometry comparison: the flat layer starts with120millionm3/m and the centered body with60millionm3/m. Perfect symmetry remaining stationary is an equilibrium observation, not evidence that a heavy-over-light layer is stable to perturbations.',
  [src('docs/FLAT_AND_CENTERED_WATER_VIDEOS.md'),src('Output/flat_and_centered_S3_videos_20261024_221928/video_comparison.json')]);
 await image(s,'flat_mechanism',62,125,805,460);
 text(s,'Flat layer',925,150,290,45,29,{bold:true});text(s,'Maximum change in phi\n1.24e-9 at 8.893 yr',925,211,290,110,28);
 text(s,'Lateral structure allows the centered body to circulate and descend.',925,375,290,165,26);
 footer(s,'Flat initial liquid: 120 million m3/m. Centered initial liquid: 60 million m3/m.');
}
// 13
{
 const s=slide('Geometry comparison movies',
  'The corrected flat calculation reaches the shared endpoint8.89348313212yr in one adaptive update. Its movie has only two actual states, initial and final, held for playback. The centered movie has107actualstates andendsatstep3357atthesametime. No perturbation was imposed in theflatlayer. Botharewarm,closedCartesian tests. Do not interpret the contrast as equal-volume or stability analysis. The flatmovie is deliberately static to reflect the available computation rather than fabricate intermediate dynamics.',
  [src('Output/flat_and_centered_S3_videos_20261024_221928/video_comparison.json'),src('Output/flat_and_centered_S3_videos_20261024_221928/video_verification.json')]);
 text(s,'Flat layer',66,153,545,40,29,{bold:true});text(s,'Centered body',666,153,545,40,29,{bold:true});
 await movie(s,'flat',64,220,552,311);await movie(s,'center_short',664,220,552,311);
 text(s,'2 actual states',66,551,545,40,26);text(s,'107 actual states',666,551,545,40,26);
 footer(s,'Both end at 8.893 years. Held frames preserve the computed states.');
}
// 14
{
 const s=slide('Warm and cold centered-body initial states',
  'The cold test copies the corrected warm centered-body solver and changes only the bottom-half initial temperature. Domainx0-20km,z-2to10km,100x120cells. Initial liquidbodyx5-15km,z4-10km,phi1;otherwisephi0. WarmcaseT273Keverywhere. Coldcasebottomhalfz-2to4kmT253.15K,upperhalf273K. The original model melting point remains273K, so the actual initial cold deficit is19.85K. Temperature is an initial condition only andevolves freely. No pore/permeability floor or fixed thermal boundary is added. Both100yeartestsretainmu_water1e-3PasandtheregularizedminimumStokescoefficient1e9Pas. Bothstartwith60millionm3liquidpermetreoutofplanedepth.',
  [src('docs/CENTERED_COLD_BOTTOM_S3.md'),src('docs/CENTERED_COLD_BOTTOM_S3.diff'),src('Output/centered_cold_bottom_S3_100yr_20261025_073337/initial_verification.json')]);
 await image(s,'initial_cold',64,126,1150,480);footer(s,'The shared flow, heat-update, and phase-recovery block remains unchanged. Both runs target 100 years.');
}
// 15
{
 const s=slide('Cold ice slows descent and retains less liquid',
  'Bothactualendpointtimesareexactly100years. Thewarmbodyhasreachedtheclosedbaseandspreadlaterally. Thecoldbodyisstillhigherandhasjustpassedz0inthecenter. Thelowestcenter-columncellwithphi>=0.5hascenterz-1.95kmwarmversus-0.05kmcold. Thisthresholdavoidscallingaverysmallupwindtailthebodyfront,butpositionsremaincell-centerestimates. Lower-halfliquidis59.4279227versus40.6104215millionm3/m. Domainnetliquidlossisnumericallyzerowarmversus4.1343711millionm3/mcoldor6.89062%initial. Thecoldruninitiallyhas5.6257timesgreaterdry-iceviscosityunderretainedArrheniuslaw. Temperaturealsoaffectsbuoyancyandphaseequilibration. Thesechangingmechanicalandthermalconditionspreventassigningtheslowertrajectorytoconductionalone.',
  [src('docs/CENTERED_WARM_COLD_CONDUCTION.md'),m.comparison+'/comparison.json']);
 await image(s,'warm_map',58,142,555,360);await image(s,'cold_map',650,142,570,360);
 text(s,'Warm: 59.43 million m3/m below z = 4 km',66,535,552,82,25,{bold:true,color:C.blue});
 text(s,'Cold: 40.61 million m3/m below z = 4 km',666,535,552,82,25,{bold:true,color:C.orange});
 footer(s,'At 100 years, cold-case effective net refreezing is 4.13 million m3/m, or 6.89% of initial liquid.');
}
// 16 native profiles, exact cell edges
{
 const s=slide('Profiles through the center at 100 years',
  'The profile uses one actualcolumnx10.1km,theright-nearestcellcolumntothedomaincenteronthe100-cellgrid. Valuesareconstantwithineach100mverticalcell. Repeatedcell-edgecoordinatesencodestaircaseswithoutinventingintermediatefieldvalues. Warmandcoldendpointsareexactly100years. Commoninitialphi1abovez4kmand0below. Warmtemperaturestays273Kwithin1.18e-9Koverallrecordedsteps. Thecoldthermalprofilemovesandwarmswiththebodyandheattransport. Atemperatureincreaseatfixedcoordinatesdoesnotmeasurewarmingofthesameoriginalmaterialparcel.',
  [m.comparison+'/center_profiles_100yr.csv',m.comparison+'/comparison.json']);
 const z=[],wp=[],cp=[],ip=[],wt=[],ct=[],it=[];
 for(const r of m.profiles){z.push((r.z_m-50)/1000,(r.z_m+50)/1000);for(const [out,key]of[[wp,'warm_phi'],[cp,'cold_phi'],[ip,'initial_phi'],[wt,'warm_T_K'],[ct,'cold_T_K'],[it,'cold_initial_T_K']])out.push(r[key],r[key]);}
 scatter(s,[{name:'Warm',xValues:wp,values:z},{name:'Cold',xValues:cp,values:z},{name:'Initial',xValues:ip,values:z}],50,140,570,470,{xTitle:'Liquid fraction',yTitle:'z [km]',xmin:0,xmax:1.03,ymin:-2,ymax:10});
 scatter(s,[{name:'Warm',xValues:wt,values:z},{name:'Cold',xValues:ct,values:z},{name:'Cold initial',xValues:it,values:z}],652,140,570,470,{xTitle:'Temperature [K]',yTitle:'z [km]',xmin:251,xmax:275,ymin:-2,ymax:10});
 footer(s,'Actual center-column cells at x = 10.1 km. Curves show cellwise constant values without spatial or temporal interpolation.');
}
// 17
{
 const s=slide('Warm and cold centered-body movies',
  'Bothnewmoviesreadallactualfullcheckpointsoftherespectivecompleted100yearrun,plusitsactualinitialstate. Warmhas996statesandcold1025statesincludinginitial;themetadataandCSVmanifestsaretheauthoritativesources. Integersframerepetitionsholdstatesbetweenupdates.Nofieldortimeinterpolationoccurs.Playbackweightsapproximatelyfollowactualtime,butdensecheckpointintervalsreceiveatleastoneframe,sotheclocksdonotalwaysadvancesynchronously.Thetemperaturecolorrangeisidenticalinbothmovies253.15to273K,andtheliquidcolorrangeis0to1.Volumeunitsarepermetreofoutofplanedepth.Bothusekc1.85e-8m2andexponent3.',
  [src('Output/centered_water_S3_100yr_20261024_214605/summary.json'),src('Output/centered_cold_bottom_S3_100yr_20261025_073337/summary.json'),m.output+'/videos/warm_frame_manifest.csv',m.output+'/videos/cold_frame_manifest.csv']);
 text(s,'Warm initial condition',66,149,548,45,29,{bold:true,color:C.blue});text(s,'Cold bottom half',666,149,548,45,29,{bold:true,color:C.orange});
 await movie(s,'warm',64,220,552,311);await movie(s,'cold',664,220,552,311);
 text(s,'273 K initially',66,553,548,40,26);text(s,'253.15 K below z = 4 km initially',666,553,548,45,26);
 footer(s,'Both movies end at 100 simulated years. Temperature and liquid fraction use the same scales.');
}
// 18
{
 const s=slide('Conduction redistributes heat locally',
  'Thecoldlower-halfexactcumulativeheatbudgetisnetadvectedenthalpy1.524291761185562e16J/m,netconductiveinput2.237050092879082e12J/m,totalgain1.5245154661948372e16J/m.Theconductivefractionis0.0146738432%ofthenetregionalgain.Thispercentagequantifiesheatcrossingthefixedlower-regionboundary.Heatconductedfromliquidtonearbyicewithinthatregioncancelsinitsnettotal.Themapshowssigned,time-integratedconductivecontributionsineachfixedcell,bothheatingandcooling.Whole-domainnetconductionisnumericallyzeroasexpectedforinsulatedwalls.Positivecumulativecellsum5.06815e12J/misbalancedbyanegativesumofthesamemagnitude.Thesearesignsoftime-integratedcellbudgets,notgrosspositive/negativeheatintegralsovertime.Thereforethesmallregionalfractiondoesnotmeanzerolocalroleorprovidethecausalfractionofmigration.',
  [m.comparison+'/comparison.json',src('model_and_dependencies/centered_cold_bottom_heat_budget.m')]);
 await image(s,'conduction_map',55,125,705,465);
 text(s,'Net lower-half heat gain',820,151,380,60,29,{bold:true});
 text(s,'0.0147%',820,236,380,80,52,{bold:true,color:C.orange});
 text(s,'from conduction',820,323,380,45,28);
 text(s,'Internal heating and cooling can cancel in this regional total.',820,421,380,130,26);
 footer(s,'The map records energy increments in fixed cells, rather than temperatures of tracked material parcels.');
}
// 19
{
 const s=slide('The first cold cell becomes wet through transport',
  'Actualfirstupdateatx10.1km,z3.95kmends0.7141750429yr.InitialT253.15K,phi0,H=-0.114739884393064.Bulkenthalpyincrement+0.115184495305557,Darcy0,conduction+0.000127719850852,finalH+0.000572330763345.ThismapsviaenthMelttophi0.000574399096742.Omittingonlytheconductiveincrementfromthatsamefrozenstepgivesphi0.000446217681966.Conductionaccountsfor0.000128181414776or22.3157%ofthesmallactualEulerianphiincreaseintheselectedcell.Conductionalonewarmsitto253.1720955Kandleavesphi0.All15540actualstepdiagnosticsgivezerodrylowercelltransitionstoliquidintheone-stepconduction-onlycheck.Thechecksreuseactualstartingstateswhichalreadyincludeearlierhistory;theyarenotseparatelyevolved100yearno-conductioncontrols.Bulkenthalpytransportincludesupwindmixing.Theeventdoesnotestablishspontaneousporeopeninginstationaryice.',
  [m.comparison+'/comparison.json',src('model_and_dependencies/enthMelt.m'),src('model_and_dependencies/centered_cold_bottom_heat_budget.m')]);
 const first=cw.conduction.first_update.center_sample;
 bar(s,['Omit conduction','Actual update'],[first.phi_advection_only*1e4,first.phi_after*1e4],60,145,700,445,{yTitle:'Liquid fraction (x 10^-4)',max:7,format:'0.000'});
 text(s,'Conduction alone',827,163,370,50,30,{bold:true});
 text(s,'253.150 K\nto 253.172 K',827,242,370,120,31);
 text(s,'phi remains zero',827,398,370,50,30,{bold:true});
 text(s,'Advection crosses the model melting threshold in this update.',827,491,370,108,25);
 footer(s,'One actual step with a fixed flow. This check does not measure the causal effect on the full 100-year trajectory.');
}
// 20
{
 const s=slide('What the tests support about migration',
  'Supportedmechanism:permeability-enhancedliquidsegregationcoupledtoviscouscompactionanddilationwithinthealreadywetregion.DryfrontwettinginthecheckedupdatesbeginswithmaterialmotionandenthalpytransportinfixedEuleriancontrolvolumes.Phiisliquidvolumefractionrecoveredfromenthalpy,notanindependentempty-pore,damageorcavitationvariable.Atanexactlydryharmonicfacek_face=q=0.Whendryfacesallhaveq0,themixtureconstraintimposesdiv(v_s)approximately0,notthevectorvelocityv_s0.Whentwoadjacentcellsarewet,positivefacepermeabilityallowssegregation.Phichangesmodifyk=kcphi3andtheexistingmelt-softeningrheology.Higherkcincreasesmobility,butpressureandiceflowadjustsospeedratiosarenot1e8.Warm/coldcomparisonsalsochangeviscosity,buoyancyandphaseequilibration.Noclaimofdry-porefracturenucleationorspatiallyconvergedinvasionspeedfollowsfromthesetests.',
  [src('docs/EUROPA_MIGRATION_SIMPLE_EXPLANATION.md'),src('docs/CENTERED_WATER_PERMEABILITY_MECHANISM.md'),src('docs/CENTERED_WARM_COLD_CONDUCTION.md')]);
 paragraphs(s,[
  'Material motion brings wet material into previously dry grid cells.',
  'Enthalpy equilibration determines how much liquid remains after transport.',
  'Connected wet material permits Darcy segregation and framework dilation.',
  'Higher permeability strengthens relative drainage as pressure and ice motion adjust.'
 ],70,151,1125,29,110);
 footer(s,'The computed sequence supports transport and wet-region segregation. Dry pore nucleation remains untested.');
}
// 21
{
 const s=slide('Numerical spreading at a dry front',
  'Thisseparateadvection-operatortestprescribesverticalvelocity-10m/year,initialphi0.2betweenz4and6km,andadvances100yearswithq0andcompactionrate0.Exactcellaveragesprovideareferencewithoutinterpolation.AtCFL0.4,theone-percenttailahead oftheexactfrontis600,400,and300mfordz100,50,and25m.ThecorrespondingrelativeintegralL1errorsare0.19339,0.13747,and0.09746.Totalvolumestaysconservedtonumericalprecision.Thisdirectlydemonstratesfirst-orderupwindspreadingandadecreasewithrefinement.ItisnotameasureofEuropaorcentered-bodyfront error,whichrequiresfullycoupledresolutionstudies.Asmallpositivecellphi canactivatepositivepermeabilityinsubsequentupdates.',
  [src('docs/EUROPA_REGULARIZATION_AUDIT.md'),src('Output/Europa_regularization_audit_20261024/regularization_audit.json')]);
 bar(s,['100 m cells','50 m cells','25 m cells'],[600,400,300],64,145,750,445,{yTitle:'One-percent tail ahead of exact front [m]',max:750,colors:[C.blue,C.blue,C.blue],format:'0'});
 text(s,'Darcy flow = 0\nCompaction = 0',872,180,335,130,30,{bold:true});
 text(s,'The transport scheme alone creates a small positive-phi tail.',872,362,335,150,27);
 footer(s,'Controlled transport benchmark. These tail lengths are not measured errors in the coupled research runs.');
}
// 22
{
 const s=slide('Constitutive and thermal limits',
  'WaterdynamicviscosityintheDarcycoefficientismu_f=1e-3Pas.Inpurewaternear273Kand0.1MPa,IAPWSgivesapproximately1.8e-3Pas.Thisisaseparatecoefficientfromthematrixshearlaw.Thecentered/Europaregularizedmatrixlawfloorsdimensionlessviscosityat1e-5withetaref1e14Pas,soitsminimumStokescoefficientis1e9Pas.Atphi1thiscontinuesthematrixrheologyanddoesnotresolvemolecularliquid-waterhydrodynamics.Theflooralonecannotprovepredictedmigrationwrong;observablesneedrheologysensitivity.Thewavebenchmarkhasotherconstitutivechoicesandnonzerobackgroundporosity.ThesolveralsoretainskappaPrime100forz<200mandphi>.5,equivalentto330W/(mK);62coldtestcellsactivateitatfinalflow.Dry-ice diffusivity1.70313e-6m2/simpliessqrt(kappat)=73.29mover100yr.The100mverticaland200mhorizontalgriddoesnotfullyresolvethatconductivelayer.Pressureconditioningwarningsandinitialphaseconsistencyalsolimitphysicalinference.',
  [src('docs/CENTERED_WARM_COLD_CONDUCTION.md'),src('model_and_dependencies/darcy_stokes_2D_centered_cold_bottom_S3.m'),'https://iapws.org/technical-guidance/release/LiquidWater']);
 paragraphs(s,[
  'Darcy water viscosity: 1e-3 Pa s. The regularized Stokes coefficient reaches a 1e9 Pa s floor.',
  'The inherited conductivity enhancement remains active in wet cells below z = 200 m.',
  'The dry-ice diffusion length is about 73 m over 100 years, compared with 100 m vertical cells.',
  'Converged front speeds and the full causal effect of conduction require additional controls.'
 ],70,145,1120,28,112);
 footer(s,'The numerical budgets identify the implemented mechanism. They do not independently validate the pure-liquid constitutive limit.');
}
// 23 appendix legacy
{
 const s=slide('Appendix: the earlier pressure-reference mismatch',
  'Earlierflatandcenteredtestsusedacopyofsimple_test_1D_noflow_basewhichlackedtheworkingS3head-referencecorrection.Theywerestopped,preserved,andreplacedwithfreshcorrectedS3runs.Theoldcenteredcontinuationstoppedatstep4979,t0.2717792053yr.Thelegacyflat1000-year-targettrialstoppedbeforeoneyear;lastsavedfullstateisstep5000,t0.3446158753yr,notitslaterlivereportedtime.InheadformP=p_water+rho_water*g*z,consistentforcingmustmatchthatpotential.Theinheritedresidualdensity945.4656kg/m3creates1243.287264Pa/mofartificialgradient.Withkc1.85e-8/mu1e-3,thisimpliesq0.0230008144m/sor725445.7m/year,matchingtheexcessivelargeq.Theinitialmaxsolidvelocityvariablechangesfrom918823.9to109.77m/yearwhenrestoringthereference.Thesamefrozenstep100Darcytransferratedropsby10.24x.ThecorrectedsharedEuroparesearchrunsandcurrentcenteredtestsdoincludethecorrection.Thesupersededtrajectoriesarehistoricaldiagnostics,notphysicalmigrationpredictions.',
  [src('docs/CENTERED_BLOB_CONTINUATION_AUDIT.md'),src('Output/centered_blob_continuation_20261024_210127/analysis/forcing_control/forcing_control.json')]);
 await image(s,'pressure_control',62,125,820,460);
 text(s,'Superseded runs',934,151,278,50,29,{bold:true,color:C.orange});
 text(s,'A missing head-reference term produced excessive phase fluxes.',934,229,278,140,27);
 text(s,'The current runs use the corrected shared S3 forcing.',934,426,278,120,27);
 footer(s,'Earlier outputs remain archived. They do not serve as evidence for the corrected migration rates.');
}
// 24
{
 const s=slide('Appendix: boundary closure checks',
  'Theearlyclosed-lidandno-flow-basechecksstartwithuniformphi0.5at273Kandrun1000iterationsforseveralkcvalues.Thetableusesclosed_lid_summary.csv.Theendpointtimesdifferstronglybecauseadaptivetimestepsdiffer:k0reaches465.405382yr,k1.85e-12reaches51.378732yr,k1.85e-8reaches0.0743481553yr.Allreportedmaterialandheatfluxesonallouterfacesareexactlyzero.Thebasalphi evolvesupto1withhighkcwhilethematerialboundaryremainsimpermeable.Thisverifiestheimplementedclosed-wallconstraintswhileallowingboundaryphasetoevolve.Theseearlytests predatethereferencecorrectionandthereforedonotvalidatephysicalmigration.Thetabledoesnotcompareequalphysicaltimes.',
  [src('Output/closed_lid_1000_steps/closed_lid_summary.csv'),src('Output/no_flow_base_1000_steps/no_flow_base_summary.csv')]);
 table(s,[['kc [m2]','Years after 1,000 steps','Maximum outer fluxes'],['0','465.405','0'],['1.85e-12','51.379','0'],['1.85e-8','0.07435','0']],62,158,1156,295,[350,430,376],27);
 text(s,'Impermeability constrains normal flux while the boundary liquid fraction evolves.',70,510,1120,100,31,{bold:true});
 footer(s,'Earlier formulation. These are boundary checks at unequal physical times, not corrected migration predictions.');
}
// 25
{
 const s=slide('Appendix: reproducibility and regularization',
  'Shared-caseregressionafteraddingcentered_waterpreservedonewaveandthreeEuropaupdatesbit-for-bitforallcomparedfullstatesandhistories.AnindependentEuropa100-stepreplicaatkc1.85e-8andexponent3matched21savedstatesandallmeltbudget/thermalhistoriesexactly,endingt0.4346621825yr.Thecorrectedcentered1-yeartrialmatchedanindependentinitialfrozenflowwithinrelative1e-8andconservedenthalpywithin5.76e-15relative.Flowepsilon1e-5to1e-7sweepsatfourfrozenEuropastateschangedmaxwhole-fieldsolidL2relativedifferenceby0.000266%;qonexactlydryfacesremained0.Thisdoesnotreplacefulltrajectorysensitivity.Aseparatezero-Darcy incompressibleStokescontrolretainsnonzerosolidmotionwithoutcompactionregularization.Thelegacyoverpressurediagnosticusesphi+1e-15whileflowusesphi+1e-5,whichcanamplifydry-cellreportedpressurewithoutfeedingbackintoflow.Themanuscriptphase-pressure-differenceconventionneednotinclude1-phi;previousclaimsofautomaticallymissing1-phiwerecorrected.Smallalgebraicresidualsdonotprovepressureaccuracyinanill-conditioned system.',
  [src('docs/EUROPA_REPRODUCIBILITY.md'),src('Output/centered_water_S3_verification_20261024_213417/verification.json'),src('docs/EUROPA_REGULARIZATION_AUDIT.md')]);
 table(s,[['Check','Result','Scope'],['Independent Europa replay','21 states identical','First 100 updates'],['Existing-case regression','Bitwise identical','1 wave / 3 Europa updates'],['Flow epsilon 1e-5 to 1e-7','Max velocity change 0.000266%','Frozen states only'],['Dry-face Darcy flux','Exactly zero','Checked states and controls']],62,148,1156,360,[410,370,376],24);
 text(s,'The pressure diagnostic and the flow use different porosity regularizations.',70,548,1120,70,27,{bold:true});
 footer(s,'Reproducibility, conservation, and residual checks establish distinct properties. None substitutes for physical convergence.');
}
// 26
{
 const s=slide('Appendix: short and interrupted tests',
  'Thisinventorydistinguishesplannedtargetsfromcompletedresults.Europasetupsmokesran3steps;theindependenthigh-kcreplayran100steps;the10,000-yearlow-kctrialwasstoppedattheuserrequestandsupersededbytheuntil-depletedresearchrun.Noclaimof10,000-yearcompletionfollowsfromitsdirectoryname.Initial-onlyoceantrialsprecededthefinaldrylower-regionchoice;finalresearchinitializationisz<0phi0,T273K.Theoldflatandcenteredlegacy-parenttrialsarepreservedbutexcludedfromcorrectedphysicalcomparisons.Thecorrectedflat8.893-yearcomparisonhas2states,thecenteredversion107,thecorrected1-yearcenteredtrial187steps,andthewarm/cold100-yearruns14708/15540steps.NoTitantrajectoryisverifiedbythisdeck.The2026researchrunstatisticsandfrozencontrolsarealltracedinslide sources.',
  [src('Output/Europa_kc_1.850e-16_10000yr_20261023_193721/STOPPED_BY_USER.txt'),src('docs/CENTERED_WATER_S3_SETUP.md'),src('docs/CENTERED_BLOB_CONTINUATION_AUDIT.md'),src('model_and_dependencies/S3_CASE_SWITCH_README.md')]);
 table(s,[['Run group','Status / use'],['Europa 3-step and 100-step trials','Setup and replay checks'],['Europa 10,000-year target','Stopped by user, superseded'],['Liquid-ocean initial-only trial','Superseded by dry lower-region initialization'],['Old flat / centered parent','Archived with known reference bias'],['Corrected centered 1-year trial','Completed, 187 steps'],['Warm / cold centered 100-year tests','Completed, 14,708 / 15,540 steps']],62,140,1156,423,[500,656],23);
 footer(s,'Directory targets are not completion claims. All primary conclusions use identified corrected outputs.');
}
// 27
{
 const s=slide('Files for continuing the analysis',
  'Primaryworkingentries:run_darcy_stokes_case.manddarcy_stokes_2D_cases.mforwave/Europa/warmcentered;run_Europa_until_depleted.mforthecompletedimpactresearchruns;run_centered_water_S3.mforthewarmbox;run_centered_water_cold_bottom_S3.manddarcy_stokes_2D_centered_cold_bottom_S3.mfortheseparatecoldcopy.Thecoldandwarmactiveexecutableswerefrozenindistinctsourcefolders.Output/sourceandJSONhashmanifestsidentifytheactualusedbytes.The100yearconductioncomparisonhasexactcenterprofilesCSVandcelwiseheatbudgets.Mainoutputdocuments:docs/CENTERED_WARM_COLD_CONDUCTION.md,docs/CENTERED_WATER_PERMEABILITY_MECHANISM.md,docs/EUROPA_FACE_FLUX_PROOF.md,docs/EUROPA_DILATION_EVIDENCE.md.Theslidescontainnativeeditabletables/charts.ThemovieobjectsembedMP4bytesandstandalonecopiesaccompanythedeck.',
  [src('model_and_dependencies/run_darcy_stokes_case.m'),src('model_and_dependencies/run_Europa_until_depleted.m'),src('model_and_dependencies/run_centered_water_S3.m'),src('model_and_dependencies/run_centered_water_cold_bottom_S3.m'),src('docs/CENTERED_WARM_COLD_CONDUCTION.md'),m.comparison+'/comparison.json']);
 paragraphs(s,[
  'Shared solver: darcy_stokes_2D_cases.m',
  'Cold test: darcy_stokes_2D_centered_cold_bottom_S3.m',
  'Exact profiles and heat budgets accompany the 100-year comparison.',
  'Speaker notes identify source runs, assumptions, and figure provenance.'
 ],70,150,1120,30,108);
 footer(s,'Seven movies accompany the presentation. Their recorded simulation clocks and source states remain explicit.');
}

const notes=JSON.parse(await fs.readFile(path.join(B,'research_notes.json'),'utf8'));
for(let i=0;i<p.slides.items.length;i++)p.slides.items[i].speakerNotes.text=notes[String(i+1)]+'\n\nSources\n'+slideIndex[i].sources.join('\n');
await fs.writeFile(path.join(B,'video_slots.json'),JSON.stringify(videoSlots,null,2));
await fs.writeFile(path.join(B,'slide_index.json'),JSON.stringify(slideIndex,null,2));
await fs.writeFile(path.join(B,'requirements.json'),JSON.stringify({requiredNativeTableOwnerSlides:[...new Set(tableOwners)],requiredNativeChartOwnerSlides:[...new Set(chartOwners)],fontPolicy:{basis:'user_request',families:[F]},slideCount:p.slides.items.length},null,2));
await (await PresentationFile.exportPptx(p)).save(path.join(B,'candidate_base.pptx'));
console.log('DECK_EXPORTED',p.slides.items.length,'slides',videoSlots.length,'movie slots');
for(let i=0;i<p.slides.items.length;i++){
 const slide=p.slides.items[i];const blob=await p.export({slide,format:'png',scale:1});
 await fs.writeFile(path.join(B,'renders',`slide_${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await blob.arrayBuffer()));
 console.log('RENDER',i+1);
}
console.log('DECK_RENDERED');
