///////////////////////////////////
// Author: Jyothsna Suresh
// Date  : Jan 3, 2017
// This script is an automated-batch-processing-pipeline that analyzes 3-channel images (presynaptic, puncta, post-synaptic puncta and dendrites)
// and computes the number of synapses within each image (a synapse is identified as colocalized pre- and post-synaptic puncta on top of a dendrite)
// To identify the number of false-positives due to random chance colocalization of pre- and post-synaptic puncta, we use the spatial correlation 
// property between pre- and post-synaptic puncta.
// Input data: 3-channel images, corresponding to pre-synapctic puncta, post-synaptic puncta and dendrites
// Image analysis techniques used: maximum intensity projections, rolling-ball background subtraction, median filter, image segmentation using
// thresholding, correlation analysis
// Outputs Results:Images highlighted with identified target features (synapses), as well as synaptic-count per image captured in csv file.
// On running the script, you will be prompted to locate a target folder, containing the images to be analyzed.
// The script expects the deconvolved and separate z-plane images, for each of the following channels: pre-syn channel, post-syn channel and dendritic channel.


/////////////Initialization Steps
// sets white pixels as 255, black as 0
run("Options...", "iterations=1 count=1 black"); 
run("Colors...", "foreground=black background=white selection=yellow");
//This runs the script in batch mode.Images will not be displayed, speeding up the computation.
setBatchMode(true);      
RandImgNoOfPixels = 1024;
totImgPixels = RandImgNoOfPixels*RandImgNoOfPixels;
x_length_in_Micrometers = 51.2;
y_length_in_Micrometers = 51.2;
//Reporting synaptic density in terms of No. of synapses/100 sq.um dendritic area
ConversionFactorPixelsToAreaInMicroM = x_length_in_Micrometers*y_length_in_Micrometers/(totImgPixels*100);
//The threshold intensity values for pre- and post-synaptic puncta channel are set as the percentage 
//of overall pixel intensity distribution
PreSynThreshPerc = 0.45;
PostSynThreshPerc = 0.45;
run("Set Measurements...", "area mean standard min centroid area_fraction redirect=None decimal=3");
if(isOpen("Channels Tool..."))
{
	close("Channels Tool...");	
}
if(isOpen("Results"))
{
	selectWindow("Results");
	run("Close");
}
if(isOpen("Log"))
{
   // Clears the log file	
	print("\\Clear");
}
while (nImages>0) 
{ 
          selectImage(nImages); 
          close(); 
} 

// prompts the user to select the folder to be processed
dir = getDirectory("Choose a Directory ");       
// gives ImageJ a list of all files in the folder to work through
list = getFileList(dir);   
print(dir);
print("CompleteFileName,DensityOfSynapsesOnDendriticAreaOrig,DensityOfSynapsesOnDendriticAreaRand,DensityOfSynPerDendriticAreaFinal,SNR");
for (f=0; f<list.length; f++) 
{	
	 

	if(isOpen("Summary"))
	{
		selectWindow("Summary");
		run("Close");
	}
    run("Clear Results");
	
    // main files loop (process every image until you get to the bottom of the list)
    showProgress(f, list.length);   
    if (endsWith(list[f],"z000_ch00.tif"))
    {	
    	while (nImages>0) 
   	    { 
            selectImage(nImages); 
            close(); 
        } 	
		//Closing all images from previous iterations
		close("RandMaxPreSyn*");
		close("RandMaxPreSyn*");
		close("BinaryMaskRandmizedPreSyn*");
		close("RandMaxPostSyn*");
		close("RandMaxPostSyn*");
		close("BinaryMaskRandmizedPostSyn*");

/////////// Step1: Creating Maximum Intensity Projections for post-synaptic, pre-synaptic, dendritic channels
        // 1.1 Post-synaptic channel
      	// File names ending with _ch00.tif correspond to post-synaptic channel images in our example.
      	csOnlyTheCompleteFileName = replace(list[f],"z000_ch00.tif","");
  		open(dir+csOnlyTheCompleteFileName+"z000_ch00.tif");
		open(dir+csOnlyTheCompleteFileName+"z001_ch00.tif");
		open(dir+csOnlyTheCompleteFileName+"z002_ch00.tif");
    	run("Images to Stack", "name=MaxIntProj_PostSynChn title=ch00 use");
  		run("Z Project...", "projection=[Max Intensity]");
  		rename("MAXIMUM_INT_Proj_PostSynChn");
  		run("Duplicate...", "title=Extracted_PostSynChn");
   		// Rolling ball subtraction
		run("Subtract Background...", "rolling=4");
		run("Subtract Background...", "rolling=4");
		// Median filter to remove point noises
		run("Median...", "radius=3"); 
		
		// 1.2 Pre-synaptic channel
		// File names ending with _ch03.tif correspond to post-synaptic channel images in our example.
  		open(dir+csOnlyTheCompleteFileName+"z000_ch03.tif");
  		open(dir+csOnlyTheCompleteFileName+"z001_ch03.tif");
    	open(dir+csOnlyTheCompleteFileName+"z002_ch03.tif");
    	run("Images to Stack", "name=MaxIntProj_PreSynChn title=ch03 use");
  		run("Z Project...", "projection=[Max Intensity]");
  		rename("MAXIMUM_INT_Proj_PreSynChn");
  		run("Duplicate...", "title=Extracted_PreSynChn");
  		// Rolling ball subtraction
		run("Subtract Background...", "rolling=4");
		run("Subtract Background...", "rolling=4");
		// Median filter to remove point noises
		run("Median...", "radius=3");

	    // 1.3 Dendritic channel
		// File names ending with _ch01.tif correspond to dendritic channel images.
  		open(dir+csOnlyTheCompleteFileName+"z000_ch01.tif");
  		open(dir+csOnlyTheCompleteFileName+"z001_ch01.tif");
    	open(dir+csOnlyTheCompleteFileName+"z002_ch01.tif");
    	run("Images to Stack", "name=MaxIntProj_DendritesChn title=ch01 use");
  		run("Z Project...", "projection=[Max Intensity]");
  		rename("MAXIMUM_INT_Proj_DendChn");
  		run("Duplicate...", "title=Extracted_DendChn");
  	
	
/////////// STEP2: DENDRITIC CHANNEL - Setting thresholds and creating binary masks
  		
  		//2.1 Creating dendritic mask from thresholded image
  		//Threshold is : Mean pixel intensity value
		selectWindow("Extracted_DendChn");
		run("Duplicate...", "title=DendritesChn");
		if(isOpen("Results"))
		{
			selectWindow("Results");
			run("Close");
		}
		run("Measure");
    	myLowThresh =  getResult("Mean");
		myHighThresh = getResult("Max");
		setAutoThreshold("Default dark");
		setThreshold(myLowThresh, myHighThresh);
		run("Convert to Mask");
		rename("BinaryMaskDendrite");
		//Dilate the thresholded mask to account for any missed puncta in the vicinity.
		run("Dilate");
		run("Dilate");
		run("Dilate");
		run("Dilate");
		
		//Calculating Dendritic Area
		nBins = 256;
		selectWindow("BinaryMaskDendrite");
		getHistogram(values, count, nBins); 
		DendriticMaskAreaInPixels = count[255];
		NonDendriticMaskAreaInPixels = parseInt(totImgPixels) - parseInt(DendriticMaskAreaInPixels);

/////////// STEP3: PRE-SYNAPTIC CHANNEL - Creating a thresholded image and then binary masks
				//3.1 Creating multiple copies of the original image for later use.
				    selectWindow("Extracted_PreSynChn");
				    run("Duplicate...", "title=Extracted_PreSynChn-1");
				    run("Duplicate...", "title=Extracted_PreSynChn-2");
				//3.2 Calculate the max. intensity in pre-synptic channel, to be used to set upper-bound threshold on the original image
					run("Clear Results");
					selectWindow("Extracted_PreSynChn-2");
					run("Measure");
					PreSynHighThresh = getResult("Max");  
			   	//3.3 Detemine the lower-bound threshold to be set on the image
			    // This corresponds to the pixel intensity value corresponding to a certain %age (=PreSynThreshPerc) of overall pixel intensity distribution
    				nBins =256; 
					getHistogram(values, count, nBins); 
					if(values[0] == 0)
					{
						totImgPixelsAdjustedC1 = totImgPixels-count[0];	
						iStartC1 = 1;					
					}
					else
					{
						totImgPixelsAdjustedC1 = totImgPixels;
						iStartC1 = 0;	
					}
					PreSynLowThresh = 13;
					prevArea = 0;
					percentArea = 0;
					totArea = 0;
					
    				for(i=iStartC1;i<nBins;i++) 
					{
						percentArea = count[i]/totImgPixelsAdjustedC1;
						totArea = percentArea+prevArea;
						prevArea = totArea;
	    				if(totArea > PreSynThreshPerc)
						{
							if(values[i] < 1)
								PreSynLowThresh = values[i+1];
							else
								PreSynLowThresh = values[i];
							i = 9999;//This is break out of the loop
						}
					}
			    //3.4 Apply the high and low threshold intensities on the pre-synaptic channel as determined in steps 3.2 and 3.3
			    //The resulting image ThresholdedPreSynSignal will contain all intensities above the threshold value determined
			    //in step 3.3
				    run("Clear Results");
					selectWindow("Extracted_PreSynChn-2");
     				setAutoThreshold("Default dark");
					setThreshold(PreSynLowThresh, PreSynHighThresh);
					setOption("BlackBackground", true);
					run("Despeckle");
					run("Convert to Mask");
					run("Remove Outliers...", "radius=2 threshold=PreSynLowThresh which=Bright");
					run("Subtract...", "value=254");
					rename("PreSynMultiplyMask");
					imageCalculator("MULTIPLY create", "Extracted_PreSynChn-1","PreSynMultiplyMask");
					rename("ThresholdedPreSynSignal"); // This is the thresholded image.
         			//Close the threshold multiply mask
					selectWindow("PreSynMultiplyMask");
					run("Close");
				//3.5 Create the binary mask containing 5 pixel-wide circles corresponding to each puncta
					selectWindow("ThresholdedPreSynSignal");
					run("Find Maxima...", "noise=1 output=[Point Selection]");
					run("Enlarge...", "enlarge=2 pixel");
					run("Create Mask");
					rename("BinaryMaskPreSyn");
     				selectWindow("ThresholdedPreSynSignal");
					run("Find Maxima...", "noise=1 output=Count");
					selectWindow("BinaryMaskPreSyn");
					run("Dilate");
					noOfPreSynPuncta = getResult("Count",0);
				    
				//3.6 CREATE RANDOMIZED BINARY puncta mask - Presynaptic puncta channel
			   //Create new mask containing same number of puncta, but in randomized locations in the mask
			        run("Colors...", "foreground=black background=white selection=yellow");
					newImage("RandMaxPreSyn","8-bit", RandImgNoOfPixels, RandImgNoOfPixels, 1);
					for(i=0; i<noOfPreSynPuncta; i++)
					{
						xRand = random*RandImgNoOfPixels;
						yRand = random*RandImgNoOfPixels;
						setPixel(xRand,yRand,0);
					}
					run("Invert");
					updateDisplay();
					rename("RandMaxPreSyn");
					//setOption("BlackBackground", true);
					run("Create Selection");
					run("Enlarge...", "enlarge=2 pixel");
					run("Create Mask");
					rename("BinaryMaskRandmizedPreSyn");

/////////// STEP4: POST-SYNAPTIC CHANNEL - Creating a thresholded image and then binary masks
				//4.1 Creating multiple copies of the original image for later use.
				    selectWindow("Extracted_PostSynChn");
				    run("Duplicate...", "title=Extracted_PostSynChn-1");
				    run("Duplicate...", "title=Extracted_PostSynChn-2");
				//4.2 Calculate the max. intensity in post-synptic channel, to be used to set upper-bound threshold on the original image
					run("Clear Results");
					selectWindow("Extracted_PostSynChn-2");
					run("Measure");
					PostSynHighThresh = getResult("Max");  
			   	//4.3 Detemine the lower-bound threshold to be set on the image
			    // This corresponds to the pixel intensity value corresponding to a certain %age (=PostSynThreshPerc) of overall pixel intensity distribution
    				nBins =256; 
					getHistogram(values, count, nBins); 
					if(values[0] == 0)
					{
						totImgPixelsAdjustedC1 = totImgPixels-count[0];	
						iStartC1 = 1;					
					}
					else
					{
						totImgPixelsAdjustedC1 = totImgPixels;
						iStartC1 = 0;	
					}
					PostSynLowThresh = 13;
					prevArea = 0;
					percentArea = 0;
					totArea = 0;
					
    				for(i=iStartC1;i<nBins;i++) 
					{
						percentArea = count[i]/totImgPixelsAdjustedC1;
						totArea = percentArea+prevArea;
						prevArea = totArea;
	    				if(totArea > PostSynThreshPerc)
						{
							if(values[i] < 1)
								PostSynLowThresh = values[i+1];
							else
								PostSynLowThresh = values[i];
							i = 9999;//This is break out of the loop
						}
					}

			    //4.4 Apply the high and low threshold intensities on the post-synaptic channel as determined in steps 3.2 and 3.3
				    run("Clear Results");
					selectWindow("Extracted_PostSynChn-2");
     				setAutoThreshold("Default dark");
					setThreshold(PostSynLowThresh, PostSynHighThresh);
					setOption("BlackBackground", true);
					run("Despeckle");
					run("Convert to Mask");
					run("Remove Outliers...", "radius=2 threshold=PostSynLowThresh which=Bright");
					run("Subtract...", "value=254");
					rename("PostSynMultiplyMask");
					imageCalculator("MULTIPLY create", "Extracted_PostSynChn-1","PostSynMultiplyMask");
					rename("ThresholdedPostSynSignal"); // This is the thresholded image.
         			//Close the threshold multiply mask
					selectWindow("PostSynMultiplyMask");
					run("Close");

				//4.5 Create the binary mask containing 5 pixel-wide circles corresponding to each puncta
					selectWindow("ThresholdedPostSynSignal");
					run("Find Maxima...", "noise=1 output=[Point Selection]");
					run("Enlarge...", "enlarge=2 pixel");
					run("Create Mask");
					rename("BinaryMaskPostSyn");
					selectWindow("ThresholdedPostSynSignal");
					run("Find Maxima...", "noise=1 output=Count");
					selectWindow("BinaryMaskPostSyn");
					run("Dilate");
					noOfPostSynPuncta = getResult("Count",0);
					
				//4.6 CREATE RANDOMIZED BINARY puncta mask - Postsynaptic puncta channel	
			   //Create new mask containing same number of puncta, but in randomized locations in the mask
					newImage("RandMaxPostSyn","8-bit", RandImgNoOfPixels, RandImgNoOfPixels, 1);
					for(i=0; i<noOfPostSynPuncta; i++)
					{
						xRand = random*RandImgNoOfPixels;
						yRand = random*RandImgNoOfPixels;
						setPixel(xRand,yRand,0);
					}
					updateDisplay();
					run("Invert");
					rename("RandMaxPostSyn");
					setOption("BlackBackground", true);
					run("Create Selection");
					run("Enlarge...", "enlarge=2 pixel");
					run("Create Mask");
					rename("BinaryMaskRandmizedPostSyn");
					
/////////// STEP5: COLOCALIZATION ANALYSIS : Detecting to total number of puncta colocalizations on the dendrites
			
				if(isOpen("Summary"))
				{
					selectWindow("Summary");
					run("Close");
				}
				run("Clear Results");

		//5.1 Binary AND between BinaryMaskPreSyn and BinaryMaskPostSyn,Then Binary AND this result with BinaryMaskDendrite
	    // This corresponds to total number of detected synapses on the dendrites, including random chance colocalizations	
				imageCalculator("AND create", "BinaryMaskPreSyn","BinaryMaskPostSyn");
				selectWindow("Result of BinaryMaskPreSyn");
				rename("AllSynapses");
				run("Find Maxima...", "noise=1 output=[Point Selection]");
				run("Create Mask");
				rename("MaskAllSyn");
    			imageCalculator("AND create", "MaskAllSyn","BinaryMaskDendrite");
				selectWindow("Result of MaskAllSyn");
				run("Find Maxima...", "noise=1 output=[Point Selection]");
				run("Enlarge...", "enlarge=2 pixel");
				run("Create Mask");
    			rename("BinaryMaskDetectedSynapsesOnDendrites");
		        // Count number of synapses on dendrites	
				run("Clear Results");
				selectWindow("Result of MaskAllSyn");
				run("Find Maxima...", "noise=1 output=Count");
				noOfDendSynOrig = getResult("Count",0);
				//ConversionFactorPixelsToAreaInMicroM = ConversionFactorPixelsToAreaInMicroM*2;
				close("MaskAllSyn");
				close("MaskSynOnDendrites");
				close("AllSynapses");

/////////// STEP6: COLOCALIZATION ANALYSIS : Detecting number of random chance puncta colocalizations on the dendrites.
				//////////////////////////////////////// NOISE CALCULATIONS //////////////////////////////////////////////////////////////////////
				if(isOpen("Summary"))
				{
					selectWindow("Summary");
					run("Close");
				}
				run("Clear Results");

		//6.1 Binary AND between BinaryMaskRandmizedPreSyn and BinaryMaskRandmizedPostSyn,Then Binary AND this result with BinaryMaskDendrite
	    // This corresponds to total number of random chance puncta colocalizations on the dendrites	
	    		setOption("BlackBackground", true);
      			imageCalculator("AND create", "BinaryMaskRandmizedPreSyn","BinaryMaskRandmizedPostSyn");
     			selectWindow("Result of BinaryMaskRandmizedPreSyn");
     			//waitForUser;
				rename("RandAllSynapses");
				//selectWindow("RandAllSynapses");
				run("Find Maxima...", "noise=1 output=[Point Selection]");
				
				//waitForUser;
				run("Create Mask");
				rename("RandMaskAllSyn");
				run("Clear Results");
				selectWindow("RandMaskAllSyn");
				run("Find Maxima...", "noise=1 output=Count");
				noOfAllSynRand = getResult("Count",0);
	         	imageCalculator("AND create", "RandMaskAllSyn","BinaryMaskDendrite");
				selectWindow("Result of RandMaskAllSyn");
				rename("BinaryMaskRandomChanceSynOnDendrites");
				selectWindow("BinaryMaskPostSyn");
				run("Erode");
		        //Count number of random chance synapses on dendrites	
				run("Clear Results");
				selectWindow("BinaryMaskRandomChanceSynOnDendrites");
				run("Find Maxima...", "noise=1 output=Count");
				selectWindow("BinaryMaskPreSyn");
				run("Erode");
				noOfDendSynRand = getResult("Count",0);
    			close("RandMaskAllSyn");
				close("RandMaskSynOnDendrites");
				close("RandAllSynapses");
			    close("BinaryMaskRandomChanceSynOnDendrites");
			    close("Threshold*");
			    close("MaxIntProj*");
			    close("Result*");

/////////// STEP7: COLOCALIZATION ANALYSIS : Subtracting number of total detections (step5) and number of random chance detections (step6)

			 //1. Number of synapses
	   		    noOfSynAfterCorrections = parseInt(noOfDendSynOrig) - parseInt(noOfDendSynRand);
	
	        //2. Conversion of dendritic area from pixels to sq.mm
	   		    AreaInMicrometerSqOnlyDendritic = DendriticMaskAreaInPixels*ConversionFactorPixelsToAreaInMicroM;
	
	 		//3. Synaptic density per dendritic area
	        // Original images
		    DensityOfSynapsesOnDendriticAreaOrig = parseInt(noOfDendSynOrig) / parseInt(AreaInMicrometerSqOnlyDendritic);
		    DensityOfSynapsesOnDendriticAreaOrig = DensityOfSynapsesOnDendriticAreaOrig/2;
		    // Randomized images
		    DensityOfSynapsesOnDendriticAreaRand = parseInt(noOfDendSynRand) / parseInt(AreaInMicrometerSqOnlyDendritic);
		    DensityOfSynapsesOnDendriticAreaRand = DensityOfSynapsesOnDendriticAreaRand/2;
		    // NoiseCorrected FINAL SYNAPTIC DENSITY
		    DensityOfSynPerDendriticAreaFinal = parseFloat(DensityOfSynapsesOnDendriticAreaOrig) - parseFloat(DensityOfSynapsesOnDendriticAreaRand);
		    // SNR
		    SNR = parseFloat(DensityOfSynPerDendriticAreaFinal) / parseFloat(DensityOfSynapsesOnDendriticAreaRand);
			print(csOnlyTheCompleteFileName+","+DensityOfSynapsesOnDendriticAreaOrig+","+DensityOfSynapsesOnDendriticAreaRand+","+DensityOfSynPerDendriticAreaFinal+","+SNR);
	 
		close("Extracted_PreSynChn-1");
		close("Extracted_PostSynChn-1");
		close("RandMaxPreSyn");
		close("RandMaxPostSyn");
	
		//Displaying Results in a composite image	
		selectWindow("BinaryMaskDetectedSynapsesOnDendrites");
		run("16-bit");
		selectWindow("MAXIMUM_INT_Proj_PreSynChn");
		run("Enhance Contrast", "saturated=0.35");
		selectWindow("MAXIMUM_INT_Proj_DendChn");
		run("Enhance Contrast", "saturated=0.35");
		selectWindow("MAXIMUM_INT_Proj_PostSynChn");
		run("Enhance Contrast", "saturated=0.35");
		
		run("Merge Channels...", "c1=MAXIMUM_INT_Proj_PreSynChn c2=MAXIMUM_INT_Proj_DendChn c3=MAXIMUM_INT_Proj_PostSynChn c4=BinaryMaskDetectedSynapsesOnDendrites create keep");
		Stack.setActiveChannels("1111");
		run("Channels Tool...");
		waitForUser("Please look at the Composite Image to check Synapse Detections");
 } //end of if ends with

}// end of for
setBatchMode("exit and display");
showStatus("finished");

