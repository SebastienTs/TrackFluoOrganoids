////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Name: 		TrackFluoOrganoids
//// Author: 	Sébastien Tosi (sebastien.tosi@gmail.com)
//// Version: 	1.0
//// Date:		09/10/2024
////
//// Aim:		Segment & track fluorescent organoids in a 2D time-lapse
////
//// Requirements: - IJPB-plugins (Help > Update > Manage update sites > Tick IJPB-plugins and update)
////			   - Copy "Random" LUT to ImageJ luts folder
////
//// Usage:		- Launch the macro
////			- Open the time-lapse when asked
////			- Mark the objects to track with ImageJ multi-point tool (optional, all objects tracked for no marker)
////
////			In case the segmentation/tracking is not satisfactory, adjust the parameters (first macro section)
////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Segmentation: Geometrical parameters
GaussRad = 1;			// Pixels, increase to reduce noise / smooth object contours
BckRad = 250;			// Pixels, set around 3x-4x the radius of the largest objects
ThrRad = 75;			// Pixels, set around 2x the the radius of the largest objects
MinArea = 750;			// Pixels, area of the smallest object to be kept (small objects clumped to larger ones kept)
// Segmentation: Intensity parameters
Range = 4000;			// Characteristic objects intensity range (saturate above before thresholding)
ThrLvl = -1;			// Segmentation threshold, the more negative, the less sensitive
MeanIntThr = 750;		// Minimum mean intensity of the weakest objects to be kept
// Tracking parameters
TrackErodeRadXY = 6;	// Pixels, tracking tolerance, increase if neighbor objects merge to same ID over time
TrackErodeRadZ = 1;		// frames, disappearance tolerance, increase if objects are unstable (change ID over time)
OutlinesOnly = true;	// Only display object outlines (objects fully inside the thick contours)

// Initialization
run("Options...", "iterations=1 count=1 do=Nothing");

// Open Image
run("Close All");
waitForUser("- Open 2D time-lapse\n- Optionally mark the objects to be tracked in the first frame");
resetMinAndMax();

// Initialization
Original = getTitle();
run("Set Measurements...", "area mean standard redirect=["+Original+"] decimal=2");
Cleanup();
getPixelSize(pixelUnit, pixelWidth, pixelHeight);
setBatchMode(true);

// Optional seeds
if(selectionType()==10)
{
	Seeds = true;
	getSelectionCoordinates(xpoints, ypoints);
}
else Seeds = false;
selectImage(Original);
run("Select None");

// Thresholding
run("Duplicate...", "title=Copy duplicate");
run("Gaussian Blur...", "sigma="+d2s(GaussRad,2)+" stack");
run("Subtract Background...", "rolling="+d2s(BckRad,0)+" stack");
setMinAndMax(0, Range);
run("8-bit");
run("Auto Local Threshold", "method=Mean radius="+d2s(ThrRad,0)+" parameter_1="+d2s(ThrLvl,0)+" parameter_2=0 white stack");
run("Analyze Particles...", "size="+d2s(MinArea,0)+"-Infinity pixel show=Masks display exclude clear include add in_situ stack");
close();

// Only keep bright objects + split
newImage("Mask", "8-bit black", getWidth(),getHeight(), nSlices());
N = roiManager("count");
for(i=0;i<N;i++)
{
	if(getResult("Mean",i) >= MeanIntThr)
	{
		roiManager("select", i);
		run("Set...", "value=255 slice");
	}
}
setThreshold(1,255);
run("Convert to Mask", "method=Default background=Dark");
run("Watershed", "stack");
Cleanup();

// Track
selectImage("Mask");
Stack.setDimensions(1, nSlices, 1);
run("Minimum...", "radius="+d2s(TrackErodeRadXY,0)+" stack");
run("Minimum 3D...", "x=1 y=1 z="+d2s(TrackErodeRadZ,0));
run("Connected Components Labeling", "connectivity=26 type=[16 bits]");
run("Maximum 3D...", "x=1 y=1 z="+d2s(TrackErodeRadZ,0));
run("Maximum...", "radius="+d2s(TrackErodeRadXY,0)+" stack");
run("Random");
selectImage("Mask");
close();

if(Seeds)
{
	selectImage("Mask-lbl");
	KeptIDs = "";
	for(i=0;i<lengthOf(xpoints);i++)KeptIDs = KeptIDs+d2s(getPixel(xpoints[i], ypoints[i]),0)+", ";
	run("Select Label(s)", "label(s)=["+KeptIDs+"]");
	NewLabel = getImageID();
	selectImage("Mask-lbl");
	close();
	selectImage(NewLabel);
	run("Remap Labels");
	rename("Mask-lbl");
}

// Display results
selectImage("Mask-lbl");
Stack.getStatistics(voxelCount, mean, min, max);
for(i=0;i<nSlices;i++)
{
	setSlice(i+1);
	getHistogram(values, counts, 65536);
	for(j=1;j<=max;j++)setResult("Time"+d2s(i,0),j-1,counts[j]*pixelWidth*pixelHeight);
}
updateResults();
IJ.renameResults("Results","Area ("+pixelUnit+"^2)");

selectImage("Mask-lbl");
if(OutlinesOnly)
{
	run("Duplicate...", "title=Copy duplicate");
	run("Minimum...", "radius=1 stack");
	imageCalculator("Subtract stack", "Mask-lbl","Copy");
	selectImage("Copy");
	close();
	selectImage("Mask-lbl");
	run("Maximum...", "radius=1 stack");
}
run("Merge Channels...", "c1=Mask-lbl c4=["+Original+"] create");
run("Channels Tool...");
run("Set Measurements...", "area mean standard decimal=2");
Stack.setDimensions(2, 1, nSlices/2);
Stack.setChannel(2);
run("Enhance Contrast", "saturated=0.5");
Stack.setChannel(1);
setBatchMode("exit & display");

// Cleanup
function Cleanup()
{
	if(isOpen("ROI Manager"))
	{
		selectWindow("ROI Manager");
		run("Close");
	}
	if(isOpen("Results"))
	{
		selectWindow("Results");
		run("Close");
	}
}
