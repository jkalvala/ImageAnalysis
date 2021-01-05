     // Image Processing - Thresholding (creating a binary image from a raw RGB image)
     // Author : Jo suresh
     // Date : June 25, 2015
     // This is an "ImageJ" batch processing script that can take raw RGB images as inputs and spits out the thresholded binary images.
     
     
     // prompts the user to select the folder to be processed, stores the folder as the destination for saving
	 dir = getDirectory("Choose a Directory ");      
	 
	 // gives ImageJ a list of all files in the folder to work through
     list = getFileList(dir);   

	 // Clears the log file	
     print("\\Clear");
	 
	 //prints the number of files in the folder
	 print(list.length);   

    //setBatchMode(true);               
    for (f=0; f<list.length; f++) 
	{	
	    // main files loop (process every image until you get to the bottom of the list), { means open a loop
        path = dir+list[f];                                                    
        showProgress(f, list.length);     
 	    if (endsWith(list[f]," - C=0.tif")) 
		   {		
		    open(path);
		    start = getTime();           
			//optional get start time to see how long a process will take.  Goes with last line print time
			t=getTitle();                                       
			csOrigFileName = replace(t," - C=0.tif","");   
			
	
			// ************** STEP3 - Counting Dendritic lengths
			open(replace(t," - C=0.tif"," - C=1.tif"));
			selectWindow(csOrigFileName + " - C=1.tif");
			run("Z Project...", "start=1 stop=3 projection=[Max Intensity]");
			print("Successfuly ran Z-project");
			run("Gaussian Blur...", "sigma=1");
			run("Subtract Background...", "rolling=3 sliding");
			run("Threshold...");
			setAutoThreshold("Li dark");
			waitForUser("check the threshold, then press OK");
			
			run("Create Mask");
			run("Duplicate...", "title=[fat map2]");
			setOption("BlackBackground", true);
			run("Dilate");
			print("Dilate - SUCCESS !");
			
			
			selectWindow("fat map2");
			selectWindow("mask");
			run("Skeletonize");
			setAutoThreshold("Li dark");
			run("Measure");
			print("Measure - SUCCESS !");
			while (nImages>0) 
			{ 
				 selectImage(nImages); 
				  close(); 
			}
  
			}  //end of if C=0.tif   
 
	} // end of for loop
                                                 
	//setBatchMode("exit and display");
	showStatus("finished");
	print((getTime()-start)/1000);      // optional, goes with getTime.  Prints the amount of time taken for processing to the log file

	
	
