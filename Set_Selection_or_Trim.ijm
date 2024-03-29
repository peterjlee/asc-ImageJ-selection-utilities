/* Set selection at center of image or selection (if rectangle or oval), or as trim of image or selection
	v190227 1st version  Peter J. Lee  Applied Superconductivity Center, National High Magnetic Field Laboratory, Florida State University
	v190513 Added restore selection and preferences	in imageJ prefs (..\Users\username\.imagej\IJ_Prefs.txt).
	v190605 All options should now be working.
	v200207 Added new features, updated ASC functions, fixed missing selection path in prefs.
	v200224 Deactivated print debug lines  :-$ v200526 Just added 128 as a dimension.
	v210723 Cosmetic tweaks.
	v210823 Assumes that any selection is relevant for helping determining new selection (not just rectangles and ovals).
	v210830 Added object bounds as selection option if Table is open and columns BX(px) BY(px) are available.
	v211006 Fixed empty table and box issue.
	v211014 Fixed path issue.
	v211025 Updated functions.
	v211104 Updated stripKnownExtensionFromString function    v211112: Again
	v211208 Added "select none" and "select all" so it can replace 2 menu items. Added auto, inverse and crop options. Added image width to default options and set as maximum selection width.
	v211209 Default width NUMERICAL sorting restored. List now includes selection width if selection exists. Crop-to option removed as it is not working as expected.
	v211209d	Adds tight bounding box option.
	v211221 Restored Restore Selection. v220110 Added selected height as width option  v220120 Restored crop to selection option.
	v220202 If height cannot contain width-based aspect ration then the width will be set by the height and the aspect ratio.
	v220203 Major overhaul to reduce dialogs and allow expansion and contraction of selected ares v220204; minor tweaks.
	v220211 Added expansion option for auto-select, reorganized menus for better fit, fixed AR-based selections to respect image dimensions. Added auto selection names. v220224 Dialog tweaks
	v220310-1 Added image aspect ratio correction based on selection AR. v220316 Corrected menu description f2-f3: Updated stripKnownExtensionFromString function.
	v230803: Replaced getDir for 1.54g10. F1: Updated indexOf functions.
	*/
macro "Set Selection or Trim" {
	macroL = "Set_Selection_or_Trim_v230803-f1.ijm";
	delimiter = "|";
	prefsNameKey = "ascSetSelection.";
	prefsParaKey = prefsNameKey+"Parameters";
	prefsValKey = prefsNameKey+"Values";
	prefsPara = call("ij.Prefs.get", prefsParaKey, "None");
	prefsVal = "" + call("ij.Prefs.get", prefsValKey, "None");
	prefsParas = split(prefsPara,delimiter);
	prefsVals = split(prefsVal,delimiter);
	orImageID = getImageID();
	selectionTypeNames = newArray("rectangle","oval","polygon","freehand","traced","straight line","segmented line","freehand line","angle","composite");
	if (prefsParas.length!=prefsVals.length) {
		Dialog.create("Prefs mismatch: " + macroL);
		Dialog.addMessage(prefsParas.length + " Preference Parameters");
		Dialog.addMessage(prefsVals.length + " Preference Values");
		options = newArray("Reset prefs", "Continue", "Exit");
		Dialog.addRadioButtonGroup("Options:", options, 3, 1, "Reset prefs");
		Dialog.show();
		choice = Dialog.getRadioButton;
		if (choice == "Exit") exit("Goodbye");
		else if (choice == "Reset prefs") {
			prefsParas = newArray("none");
			prefsVals = newArray("none");
			call("ij.Prefs.set", prefsParaKey, "none");
			call("ij.Prefs.set", prefsValKey, "none");
		}
	}
	selName = "Auto-generated_name";
	getDimensions(imageWidth, imageHeight, channels, slices, frames);
	imageD = 0.5 * (imageWidth + imageHeight);
	orAR = imageWidth/imageHeight;
	objectsBounds = false;
	if (Table.size>0){
		if (Table.get("BX\(px\)", 0)>=0 && Table.get("BY\(px\)", 0)>=0 && Table.get("BoxW\(px\)", 0)>=0 && Table.get("BoxH\(px\)", 0)>=0){
			objectsBounds = true;
			BXpxs = Table.getColumn("BX\(px\)");
			Array.getStatistics(BXpxs, BXpxsMin, BXpxsMax, null, null);
			iBXpxsMax = indexOfArray(BXpxs, BXpxsMax, -1);
			BWpxs = BXpxsMax + Table.get("BoxW\(px\)", iBXpxsMax) - BXpxsMin;
			BYpxs = Table.getColumn("BY\(px\)");
			Array.getStatistics(BYpxs, BYpxsMin, BYpxsMax, null, null);
			iBYpxsMax = indexOfArray(BYpxs, BYpxsMax, -1);
			BHpxs = BYpxsMax + Table.get("BoxH\(px\)", iBYpxsMax) - BYpxsMin;
			WHDiff = BWpxs - BHpxs;
		}
	}
	selType = selectionType();
	/* Provide default or previous values */
	stdDims = newArray(128,256,384,512,768,1024,1280,1536,1920,2048,2304,3072,3840,4096,imageWidth,imageHeight);
	if (selType>=0){
		getSelectionBounds(selX, selY, selWidth, selHeight);
		startX = selX;
		startY = selY;
		newW = round(selWidth);
		newH = round(selHeight);
		orSelAR = selWidth/selHeight;
		oldSelName = selectionName;
		if (oldSelName!="") selName = oldSelName;
		// run("Select None");
		if (selType==1) selTypeName = "oval";
		else selTypeName = "rectangle";
		if ((indexOfArray(stdDims, newW, -1))<0 && newW<imageWidth) stdDims = Array.concat(stdDims,newW);
		if ((indexOfArray(stdDims, newH, -1))<0 && newH<imageHeight) stdDims = Array.concat(stdDims,newH);
	}
	else {
		selTypeName = getPrefsFromParallelArrays(prefsParas,prefsVals,"selTypeName","rectangle");
		startX = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"startX",0));
		startY = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"startY",0));
		newH = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"newH",imageHeight));
		newW = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"newW",imageWidth));
	}
	stdDims = Array.sort(stdDims);
	for (i=0; i<stdDims.length; i++){
		if(stdDims[i]>=imageWidth){
			stdDims = Array.trim(stdDims,minOf(stdDims.length,i+1));
			i = stdDims.length;
		}
	}
	stdDimsSt = newArray("");
	for (i=0; i<stdDims.length; i++) stdDimsSt[i] = d2s(stdDims[i],0);
	aspectR = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"aspectR",newW/newH));
	selAR = getPrefsFromParallelArrays(prefsParas,prefsVals,"selAR","4:3");
	if (aspectR>=1) orientation = getPrefsFromParallelArrays(prefsParas,prefsVals,"orientation","landscape");
	else orientation = getPrefsFromParallelArrays(prefsParas,prefsVals,"orientation","portrait");
	if(is("binary")) stdDims2 = newArray("fraction", "non-background");
	else  stdDims2 = newArray("fraction");
	fractW = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"fractW",0.33333));
	fractH = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"fractH",0.33333));
	startFractX = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"startFractX",(1-fractW)/2));
	startFractY = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"startFractY",(1-fractH)/2));
	trimR = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimR",0));
	trimL = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimL",0));
	trimT = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimT",0));
	trimB = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimB",0));
	rotS = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"rotS",0));
	// selName = getPrefsFromParallelArrays(prefsParas,prefsVals,"selName",selName); /* not in use, too annoying */
	addOverlay = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"addOverlay",false));
	addROI = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"addROI",false));
	saveSelection = getPrefsFromParallelArrays(prefsParas,prefsVals,"saveSelection",false);
	cropSelection = getPrefsFromParallelArrays(prefsParas,prefsVals,"cropSelection",false);
	dupSelection = getPrefsFromParallelArrays(prefsParas,prefsVals,"dupSelection",false);
	lastSelectionPath = getPrefsFromParallelArrays(prefsParas,prefsVals,"selectionPath","None");
	/* End of Default/Previous value section */

	Dialog.create("Selection choices   \(" + macroL + "\)");
		if (selType>=0) selectionText = "original selection";
		else selectionText = "center of the image";
		selectionTypes = newArray("rectangle","oval","restore selection \(Ctrl+Shift+E\)", "all \(Ctrl+A\)", "auto BB \(bounding box\)", "tight BB \(experimental\)");
		if (selType>=0) selectionTypes = Array.concat(selectionTypes, "existing within bounding box", "none \(Ctrl+Shift+A\)", "inverse");
		if(lastSelectionPath!="None") selectionTypes = Array.concat(selectionTypes,"restore last saved selection");
		if (objectsBounds){
			Dialog.addMessage("Object\(s\) bounding box: X1: " + BXpxsMin + ", Y1: " + BYpxsMin + ", Width: " + BWpxs + ", Height: " + BHpxs + ", Width-Height: " + WHDiff
			+ "\nBounding box overrides other options if selected");
			selectionTypes = Array.concat(selectionTypes,"bounding box");
		}
		iST = indexOfArray(selectionTypes,selTypeName,0);
		Dialog.addRadioButtonGroup("Selection type \('restore' and auto BB options create selections and exit\):", selectionTypes, 3, 3, selectionTypes[iST]);
		if (objectsBounds){
			Dialog.addNumber("Selection width expansion if bounding box selected",0,0,6,"pixels");
			Dialog.addNumber("Selection height expansion if bounding box selected",0,0,6,"pixels");
		}
		Dialog.setInsets(5, 20, 0); /* top, left, bottom, addNumber defaults: 5,0,3 (first field) or 0,0,3,0 */
		Dialog.addNumber("Auto-BB buffer \(expansion after auto\):",0,1,4,"0.5 * \(width+height\) in %");
		Dialog.addMessage("Tight BB \(bounding box\): Rectangular selection that excludes the background");
		Dialog.setInsets(5, 20, 0);
		Dialog.addNumber("Tight BB: Intensity tolerance:",0.01,3,4,"% \(will be slow for large values\)");
		Dialog.setInsets(3, 20, 0);
		Dialog.addNumber("Tight BB: Limits:",20,0,3,"% \(necessary for annotation bars\)");
		stdDimsF = Array.concat(stdDimsSt,stdDims2);
		stdDimsFL = lengthOf(stdDimsF);
		iDefDimsF = indexOfArray(stdDimsF, newW, stdDimsFL-1);
		buttonGroupTxt1 = "Selection width \(image width = " + imageWidth;
		if (selType>=0) buttonGroupTxt1 += " , original selection width = " + newW; 
		if (selType>=0) buttonGroupTxt1 += " , original selection height = " + newH; 
		buttonGroupTxt1 += "\):";
		if (iDefDimsF<stdDims.length) Dialog.addRadioButtonGroup(buttonGroupTxt1, stdDimsF, floor(stdDimsFL/9)+1, 9, stdDimsF[iDefDimsF]);
		else Dialog.addRadioButtonGroup("Fixed selection widths \(image width = " + imageWidth + ", image height = " + imageHeight + "\):", stdDimsF, floor(stdDimsFL/9)+1, 9, stdDimsF[iDefDimsF]);
		Dialog.addNumber("Manual width entry:","",0,10,"pixels \(change to override above\)");
		if (selType>=0)Dialog.addMessage("The 'fraction' option uses fractions of current selection for size and location \(new dialog\)");
		else Dialog.addMessage("The 'fraction' option uses fractions of current image for size and location \(new dialog\)");
		if (selType>=0) ctrType = "selection";
		else ctrType = "image";
		if (selType>=0){
			Dialog.addMessage("Trim \(negative values\ or expand selection, leave all as zero to use preset above");
			Dialog.addNumber("Left trim/expand",0,0,8,"last trim: " + trimL);
			Dialog.addNumber("Top trim/expand:",0,0,8,"last trim: " + trimT);
			Dialog.addNumber("Right trim/expand:",0,0,8,"last trim: " + trimR);
			Dialog.addNumber("Bottom trim/exp:",0,0,8,"last trim: " + trimB);
			aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "selection", "entry");
		}
		else {
			Dialog.addMessage("Override with set coordinates or trim \(negative\), leave all as zero to use preset above");
			Dialog.addNumber("Upper left X   / -left trim",0,0,8,"leave as 0 to to center on " + ctrType);
			Dialog.addNumber("Upper left Y /  -top trim:",0,0,8,"leave as 0 to to center on " + ctrType);
			Dialog.addNumber("Width         /   -right trim",0,0,8,"0 for preset above. Negative = trim");
			Dialog.addNumber("Height     / -bottom trim",0,0,8,"\"0\": Uses AR below. Negative = trim");
			aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "entry");
		}
		iAR = indexOfArray(aspectRatios,selAR,1);
		Dialog.addRadioButtonGroup("Aspect Ratio \(AR does not alter 'fraction', 'trim' or 'non-background' widths\):", aspectRatios, 1, lengthOf(aspectRatios), aspectRatios[iAR]);
		if (selType>=0){
			Dialog.setInsets(3, 20, 10); /* top, left, bottom, addCheckbox defaults: 15,20,0 (first checkbox) or 0,20,0 */
			Dialog.addCheckbox("Correct image distortion to AR above \(selection w/h is " + orSelAR + "\) by shrinking longest dimension?",false);
		}
		Dialog.addCheckbox("Orientation is Landscape \(else Portrait\)",true);
		Dialog.addNumber("Selection rotation:",rotS,5,5,"degrees");
		Dialog.addString("Selection name:",selName,30);
		checkBoxGroup1Labels = newArray("Add selection to overlay?","Add selection to ROI manager?","Save selection in image folder?","Crop to selection","Duplicate selection");
		checkBoxGroup1Defaults = newArray(addOverlay,addROI,saveSelection,cropSelection,dupSelection);
		Dialog.setInsets(3, 20, 3);
		Dialog.addCheckboxGroup(2, 3, checkBoxGroup1Labels,checkBoxGroup1Labels);
		Dialog.setInsets(3, 10, 10); /* top, left, bottom, addMessage defaults: 0,20,0 (empty string) or 10,20,0 */
		Dialog.addMessage("Use the arrow keys or mouse to move the selection after macro completion",12,"#1F497D");
	Dialog.show();
		selTypeName = Dialog.getRadioButton();
		if (objectsBounds){
			bBEnlX = Dialog.getNumber();
			bBEnlY = Dialog.getNumber();
		}
		aBuffer = Dialog.getNumber();
		tBBTolerancePc = Dialog.getNumber();
		tBBLimitsPc = Dialog.getNumber();
		selSelWidth = Dialog.getRadioButton();
		manEntry = Dialog.getNumber();
		if (manEntry!=NaN && manEntry>0) selSelWidth = manEntry;
		// print ("manEntry="+manEntry+",selSelWidth="+selSelWidth);
		startX = Dialog.getNumber;
		startY = Dialog.getNumber;
		newW = Dialog.getNumber;
		newH = Dialog.getNumber;
		selAR = Dialog.getRadioButton();
		if (selType>=0) correctAR = Dialog.getCheckbox();
		else correctAR = false;
		if (Dialog.getCheckbox()) newOr = "landscape";
		else newOr = "portrait";
		rotS = Dialog.getNumber();
		selName = Dialog.getString();
		if (selName=="") selName = "Auto-generated_name";
		else if (selName=="Auto-generated_name") selName = selTypeName + ": width = " + selSelWidth;
		/* checkBoxGroup1 */
		addOverlay = Dialog.getCheckbox();
		addROI = Dialog.getCheckbox();
		saveSelection = Dialog.getCheckbox();
		cropSelection = Dialog.getCheckbox();
		dupSelection = Dialog.getCheckbox();
	if (selAR=="1:1") aspectR = 1;
	else if (selAR=="4:3")  aspectR = 3/4;
	else if (selAR=="golden") aspectR = 1.61803398875;
	else if (selAR=="16:9") aspectR = 16/9;
	else if (selAR=="entry") {
		Dialog.create("AR menu");
		Dialog.addNumber("Set aspect ratio:", aspectR);
		Dialog.addMessage("Height will be adjusted");
		Dialog.show();
		aspectR = Dialog.getNumber();	
	}
	else aspectR = -1;
	if (newOr=="landscape") aspectR = maxOf(aspectR, 1/aspectR);
	else aspectR = minOf(aspectR, 1/aspectR);
	if (selType>=0 && correctAR && aspectR>0){
		arR = orSelAR/aspectR;
		if (arR!=1){
			arCTitle = "" + stripKnownExtensionFromString(getTitle()) + "_arC";
			// getDimensions(imageWidth, imageHeight, null, null, null);
			newImageWidth = imageWidth;
			newImageHeight = imageHeight;
			run("Select None");
			if (arR>1) newImageWidth = imageWidth/arR;
			else newImageHeight = imageHeight * arR;
			if (slices>1) run("Scale...", "x=- y=- z=1.0 width=&newImageWidth height=&newImageHeight depth=&slices interpolation=Bicubic average process create title=&arCTitle");
			else run("Scale...", "x=- y=- width=&newImageWidth height=&newImageHeight interpolation=Bicubic average create title=&arCTitle");
			selectImage(orImageID);
			run("Restore Selection");
		}
		call("java.lang.System.gc"); /* force a garbage collection */
		exit;
	}
	if(startsWith(selTypeName,"none") || startsWith(selTypeName,"restore selection") ||startsWith(selTypeName,"all") || startsWith(selTypeName,"auto") || startsWith(selTypeName,"inverse") || startsWith(selTypeName,"existing") || startsWith(selTypeName,"tight")){
		if (startsWith(selTypeName,"none")) run("Select None");
		if (startsWith(selTypeName,"restore selection")) run("Restore Selection");
		else if (startsWith(selTypeName,"all")) run("Select All");
		else if (startsWith(selTypeName,"auto")){
			run("Select None");
			run("Select Bounding Box (guess background color)");
			if (aBuffer>0) {
				enlargePix = maxOf(2,round(aBuffer * imageD/100));
				run("Enlarge...", "enlarge=&enlargePix pixel");
			}
		}
		else if (startsWith(selTypeName,"existing")) run("Select Bounding Box (guess background color)");
		else if (startsWith(selTypeName,"inverse")) run("Make Inverse");
		else if (startsWith(selTypeName,"tight")){
			showStatus("Finding tight bounding box");
			tightBoundingBox(tBBTolerancePc,tBBLimitsPc);
			showStatus("Found tight bounding box");
			if (aBuffer>0) {
				enlargePix = maxOf(2,round(aBuffer * imageD/100)); /* assume that if any umber is put in then at least 1 pixel buffer is desired */
				run("Enlarge...", "enlarge=&enlargePix pixel");
			}
		}
		if (dupSelection && selectionType()>=0){
			cropTitle = "" + stripKnownExtensionFromString(getTitle()) + "_crop";
			run("Duplicate...", "title=&cropTitle duplicate");
		}
		if (cropSelection && selectionType()>=0){
			rename("" + stripKnownExtensionFromString(getTitle()) + "_crop");
			run("Crop"); /* assume that if any umber is put in then at least 1 pixel buffer is desired */
		}
		updateDisplay();
		exit;
	}
	else if (selTypeName=="bounding box") makeRectangle(BXpxsMin-floor(bBEnlX/2), BYpxsMin-floor(bBEnlY/2), BWpxs+bBEnlX, BHpxs+bBEnlY);
	else if (selTypeName=="restore last selection"){
		run("Restore Selection");
		exit;
	}
	else if (selTypeName=="restore last saved selection"){
		open(lastSelectionPath);
		newSelType = selectionType();
		exit;
	}
	else {
		if (selTypeName=="oval") newSelType = 1;
		else newSelType = 0;
	}
	if (selType<0 && selSelWidth!="fraction"){
		if (newW>0 && newH>0){
			aspectR = newW/newH;
			selSelWidth = newW; /* just so it is not a "fraction" */
		}
		if (newH<0 || newW<0 || startX<0 || startY<0) selSelWidth="trim";
		else {
			if (newH>0 || newW>0 || startX>0 || startY>0){ 
				if (newW==0 && newH>0) {
					newW1 = round(aspectR  * newH);
					if (newW1>imageWidth){
						newW = imageWidth;
						newH = round(newH * imageWidth/newW1);
						print("Selection limited by image width to " + newW + " x " + newH);
					}
					else newW = newW1;
				}
				else if (newW>0 && newH==0){
					newH1 = round(newW/aspectR);
					if (newH1>imageHeight){
						newH = imageHeight;
						newW = round(newW * imageHeight/newH1);
						print("Selection limited by image height to " + newW + " x " + newH);
					}
					else newH = newH1;
				}
				// selSelWidth = newW;
				// selSelHeight = newH;
				newSelHeight = newH;
				newSelWidth = newW;
			}
			else if (newW==0 && newH==0){
				newSelWidth = parseFloat(selSelWidth);
				if (newSelWidth/aspectR<imageHeight) newSelHeight = round(minOf(imageHeight,newSelWidth/aspectR));
				else {
					newSelHeight = imageHeight;
					newSelWidth = round(imageHeight * aspectR);
					print("Selection limited by image height to " + newSelHeight + " x " + newSelWidth);
				}
			}
			else {
				newSelHeight = imageHeight;
				newSelWidth = round(newSelHeight * aspectR);
			}
		selSelWidth="values"; /* overrides "trim" */
		}
	}
	else {
		if (newH!=0 || newW!=0 || startX!=0 || startY!=0) selSelWidth="trim";
		else if (selSelWidth!="fraction"){
			newSelWidth = minOf(imageWidth,parseFloat(selSelWidth));
			newSelHeight =  round(newSelWidth / aspectR);
			if (newSelHeight>imageHeight){
				newSelHeight = imageHeight;
				newSelWidth = round(newSelHeight * aspectR);
				print("Selection limited by image height to " + newSelWidth + " x " + newSelHeight);
			}
		}
	}
	if (selSelWidth =="fraction" || selSelWidth =="non-background" || selSelWidth=="trim" ) {
		if (selSelWidth =="fraction") {
			Dialog.create("Fraction of original image or selection dimensions");
				if (selType!=-1) Dialog.addMessage("Original selection type = " + selectionTypeNames[selType]);
				Dialog.addMessage("New selection type = " + selectionTypeNames[newSelType]);
				Dialog.addNumber("Fraction of width", fractW);
				Dialog.addNumber("Fraction of height", fractW);
				Dialog.addNumber("Start X Fraction of width", (1-fractW)/2);
				Dialog.addNumber("Start Y Fraction of height", (1-fractW)/1);
			Dialog.show();
				fractW = minOf(1,Dialog.getNumber);
				fractH = minOf(1,Dialog.getNumber);
				startFractX = minOf(1,Dialog.getNumber);
				startFractY = minOf(1,Dialog.getNumber);

			if (selType!=-1) {
				w = maxOf(1,round(selWidth * fractW));
				h = maxOf(1,round(selHeight * fractH));
				x = maxOf(0,round(selX + selWidth * startFractX));
				if ((x+w)>imageWidth) x = imageWidth-w;
				y = maxOf(0,round(selY + selHeight * startFractY));
				if ((y+h)>imageWidth) y = imageHeight-h;
				if (newSelType==0) makeRectangle(x, y, w, h);
				else makeOval(x, y, w, h);
			}
			else {
				w = round(imageWidth * fractW);
				h = round(imageHeight * fractH);
				x = maxOf(0,round(imageWidth * startFractX));
				if ((x+w)>imageWidth) x = imageWidth-w;
				y = maxOf(0,round(imageHeight * startFractY));
				if ((y+h)>imageWidth) y = imageHeight-h;
				if (newSelType==0) makeRectangle(x, y, w, h);
				else makeOval(x, y, w, h);
			}
		}
		else if (selSelWidth =="non-background") {
			run("Create Selection");
			run("To Bounding Box");
			Dialog.create("Expand non-background selection dialog");
			Dialog.addNumber("Enlarge selection by:",0,0,5, "pixels");
			Dialog.show;
			enlargeP = Dialog.getNumber;
			if (enlargeP!=0) run("Enlarge...", "enlarge=&enlargeP pixel");
		}
		else if (selSelWidth =="trim") {
			trimL = startX;
			trimT = startY;
			trimR = newW;
			trimB = newH;
			if (selType>=0) {
				if (newSelType==0) makeRectangle(selX-trimL, selY-trimT, selWidth+trimL+trimR, selHeight+trimT+trimB);
				else makeOval(selX-trimL, selY-trimT, selWidth+trimL+trimR, selHeight+trimT+trimB);
			}
			else {
				if (newSelType==0) makeRectangle(-trimL, -trimT, imageWidth+trimL+trimR, imageHeight+trimT+trimB);
				else makeOval(-trimL, -trimT, imageWidth+trimL+trimR, imageHeight+trimT+trimB);
			}
		}
	}
	else {
		startX = maxOf(0,round((imageWidth-newSelWidth)/2));
		startY = maxOf(0,round((imageHeight-newSelHeight)/2));
		if (newSelType==0) makeRectangle(startX, startY, newSelWidth, newSelHeight);
		else makeOval(startX, startY, newSelWidth, newSelHeight);
	}
	if (rotS!=0) run("Rotate...", "  angle=&rotS");
	if (addOverlay){
		Overlay.addSelection;
		Overlay.show;
	}
	if (addROI) {
		if (selName!="Auto-generated_name" && selName!="") Roi.setName(selName);
		roiManager("Add");
	}
	if(saveSelection){
		selectionPath = getDirectory("image");
		if (!File.isDirectory(selectionPath)) selectionPath = getDirectory("Choose a Directory to save the selection information in");
		name = getInfo("image.filename");
		if (name!=0) fileName = stripKnownExtensionFromString(name);
		else fileName = File.nameWithoutExtension;
		if (name!=0) fileName = stripKnownExtensionFromString(getTitle);
		if (name!=0)	name = "Selection-" + getDateTimeCode();
		selectionPath += fileName + "_selection.roi";
		saveAs("selection", selectionPath);
	}
	else selectionPath = "None"; /* required for prefs */
	setSelectionsParasSt = "macroName|aspectR|fractW|fractH|startFractX|startFractY|iDefDimsF|newH|newW|selAR|selTypeName|newSelType|orientation|startX|startY|trimR|trimL|trimT|trimB|rotS|selName|addOverlay|addROI|saveSelection|cropSelection|dupSelection|selectionPath";
	/* string of parameters separated by | delimiter - make sure first entry is NOT a number to avoid NaN errors */
	setSelectionValues = newArray(macroL,aspectR,fractW,fractH,startFractX,startFractY,iDefDimsF,newH,newW,selAR,selTypeName,newSelType,orientation,startX,startY,trimR,trimL,trimT,trimB,rotS,selName,addOverlay,addROI,saveSelection,cropSelection,dupSelection,selectionPath);
	/* array of corresponding to parameter list (in the same order) */
	setSelectionValuesSt = arrayToString(setSelectionValues,"|");
	/* Create string of values from values array */
	call("ij.Prefs.set", prefsParaKey, setSelectionsParasSt);
	// print(setSelectionsParasSt);
	call("ij.Prefs.set", prefsValKey, setSelectionValuesSt);
	// print(setSelectionValuesSt);
	getSelectionBounds(selX, selY, selWidth, selHeight);
	showStatus("X1: " + selX + ", Y1: " + selY + ", W: " + selWidth + ", H: " + selHeight + " selected");
	if (dupSelection && selectionType()>=0){
		cropTitle = "" + stripKnownExtensionFromString(getTitle()) + "_crop";
		run("Duplicate...", "title=&cropTitle duplicate");
	}
	if (cropSelection && selectionType()>=0){
		rename("" + stripKnownExtensionFromString(getTitle()) + "_crop");
		run("Crop"); /* assume that if any umber is put in then at least 1 pixel buffer is desired */
	}
	updateDisplay();
	call("java.lang.System.gc");
	/* End of Set Selection or Trim macro */
}
	/*
		( 8(|)  ( 8(|)  ASC Functions	@@@@@:-)	@@@@@:-)
	*/
	function arrayToString(array,delimiters){
		/* 1st version April 2019 PJL
			v190722 Modified to handle zero length array */
		string = "";
		for (i=0; i<array.length; i++){
			if (i==0) string += array[0];
			else  string = string + delimiters + array[i];
		}
		return string;
	}
	function getDateTimeCode() {
		/* v211014 based on getDateCode v170823 */
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
		month = month + 1; /* Month starts at zero, presumably to be used in array */
		if(month<10) monthStr = "0" + month;
		else monthStr = ""  + month;
		if (dayOfMonth<10) dayOfMonth = "0" + dayOfMonth;
		dateCodeUS = monthStr+dayOfMonth+substring(year,2)+"-"+hour+"h"+minute+"m";
		return dateCodeUS;
	}
	function getPrefsFromParallelArrays (refArray,prefArray,ref,default){
		/* refArray has a list of parameter names and prefArray has a list of values for those parameters in the same order
		v190514  1st version v190605 corrected v200207 added array length check in if statement */
		iPref = indexOfArray(refArray,ref,-1);
		if (iPref>=0 && prefArray.length>iPref) pref = prefArray[iPref];
		else pref = default;
		return pref;
	}
	function indexOfArray(array, value, default) {
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value
			v230902 Limits default value to array size */
		index = minOf(lengthOf(array) - 1, default);
		for (i=0; i<lengthOf(array); i++){
			if (array[i]==value) {
				index = i;
				i = lengthOf(array);
			}
		}
	  return index;
	}
	function stripKnownExtensionFromString(string) {
		/*	Note: Do not use on path as it may change the directory names
		v210924: Tries to make sure string stays as string.	v211014: Adds some additional cleanup.	v211025: fixes multiple 'known's issue.	v211101: Added ".Ext_" removal.
		v211104: Restricts cleanup to end of string to reduce risk of corrupting path.	v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		v220615: Tries to fix the fix for the trapped extensions ...	v230504: Protects directory path if included in string. Only removes doubled spaces and lines.
		v230505: Unwanted dupes replaced by unusefulCombos.	v230607: Quick fix for infinite loop on one of while statements.
		v230614: Added AVI.	v230905: Better fix for infinite loop. v230914: Added BMP and "_transp" and rearranged
		*/
		fS = File.separator;
		string = "" + string;
		protectedPathEnd = lastIndexOf(string,fS)+1;
		if (protectedPathEnd>0){
			protectedPath = substring(string,0,protectedPathEnd);
			string = substring(string,protectedPathEnd);
		}
		unusefulCombos = newArray("-", "_"," ");
		for (i=0; i<lengthOf(unusefulCombos); i++){
			for (j=0; j<lengthOf(unusefulCombos); j++){
				combo = unusefulCombos[i] + unusefulCombos[j];
				while (indexOf(string,combo)>=0) string = replace(string,combo,unusefulCombos[i]);
			}
		}
		if (lastIndexOf(string, ".")>0 || lastIndexOf(string, "_lzw")>0) {
			knownExts = newArray(".avi", ".csv", ".bmp", ".dsx", ".gif", ".jpg", ".jpeg", ".jp2", ".png", ".tif", ".txt", ".xlsx");
			knownExts = Array.concat(knownExts,knownExts,"_transp","_lzw");
			kEL = knownExts.length;
			for (i=0; i<kEL/2; i++) knownExts[i] = toUpperCase(knownExts[i]);
			chanLabels = newArray(" \(red\)"," \(green\)"," \(blue\)","\(red\)","\(green\)","\(blue\)");
			for (i=0,k=0; i<kEL; i++) {
				for (j=0; j<chanLabels.length; j++){ /* Looking for channel-label-trapped extensions */
					iChanLabels = lastIndexOf(string, chanLabels[j])-1;
					if (iChanLabels>0){
						preChan = substring(string,0,iChanLabels);
						postChan = substring(string,iChanLabels);
						while (indexOf(preChan,knownExts[i])>0){
							preChan = replace(preChan,knownExts[i],"");
							string =  preChan + postChan;
						}
					}
				}
				while (endsWith(string,knownExts[i])) string = "" + substring(string, 0, lastIndexOf(string, knownExts[i]));
			}
		}
		unwantedSuffixes = newArray(" ", "_","-");
		for (i=0; i<unwantedSuffixes.length; i++){
			while (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,string.length-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
		}
		if (protectedPathEnd>0){
			if(!endsWith(protectedPath,fS)) protectedPath += fS;
			string = protectedPath + string;
		}
		return string;
	}
	function tightBoundingBox(toleranceInPc,limitsPc) {
	/* Function to create a bounding box that takes into account the maximum extent of the edge intensity
		Fitting to left-right and top-bottom are true/false.
		v211209d 1st version  Peter J. Lee
		*/
		if (toleranceInPc>=50) exit ("Tight bounding box tolerance is not sensible: " + toleranceInPc + "%");
		if (limitsPc>=50) exit ("Tight bounding box limits are not sensible: " + limitsPc + "%");
		limits = limitsPc/100;
		startBM = true;
		if (is("Batch Mode")==false){
			startBM = false;
			setBatchMode(true);
		}
		run("Duplicate...", "title=tBBTemp ignore");
		if (bitDepth()==24) run("8-bit");
		getMinAndMax(minI, maxI);
		toleranceI = toleranceInPc*(maxI-minI)/100;
		minI += toleranceI;
		maxI -= toleranceI;
		getDimensions(imageWidth, imageHeight, null, null, null);
		leftX = 0;
		rightX = imageWidth-1;
		xEnd = rightX;
		topY = 0;
		bottomY = imageHeight-1;
		yEnd = bottomY;
		progC = 0;
		progRange = 2*imageWidth + 2*imageHeight -4;
		bounds = limits*imageHeight;
		for (x=0; x<imageWidth; x++){
			showProgress(x, progRange);
			wI = getPixel(x, 0);
			if (wI<=minI || wI>=maxI){
				doWand(x, 0);
				if (selectionType()>=0){
					getSelectionBounds(startX, startY, tBBWidth, tBBHeight);
					if (tBBHeight<bounds){
						topY = maxOf(topY,tBBHeight);
						x = startX + tBBWidth;
					}
					run("Select None");
				}
			}
		}
		progC = imageWidth-1;
		for (x=0; x<imageWidth; x++){
			showProgress(x+progC, progRange);
			wI = getPixel(x, yEnd);
			if (wI<=minI || wI>=maxI){
				doWand(x, yEnd);
				if (selectionType()>=0){
					getSelectionBounds(startX, startY, tBBWidth, tBBHeight);
					if (tBBHeight<bounds){					
						bottomY = minOf(bottomY,imageHeight-tBBHeight);
						x = startX + tBBWidth;
					}
					run("Select None");
				}
			}
		}
		progC += imageWidth-1;
		bounds = limits*imageWidth;
		for (y=0; y<imageHeight; y++){
			showProgress(y+progC, progRange);
			wI = getPixel(0, y);
			if (wI<=minI || wI>=maxI){
				doWand(0,y);
				if (selectionType()>=0){
					getSelectionBounds(startX, startY, tBBWidth, tBBHeight);
					if (tBBWidth>=bounds && y>(1-limits)*imageHeight) y = imageHeight; /* To ignore annotation label at bottom */
					else if (tBBWidth<bounds){
						leftX = maxOf(leftX,tBBWidth);
						y = maxOf(y,startY + tBBHeight);
					}
					run("Select None");
				}
			}
		}
		progC += imageHeight -1;
		for (y=0; y<imageHeight; y++){
			showProgress(y+progC, progRange);
			wI = getPixel(xEnd,y);
			if (wI<=minI || wI>=maxI){
				doWand(xEnd,y);
				if (selectionType()>=0){
					getSelectionBounds(startX, startY, tBBWidth, tBBHeight);
					if (tBBWidth>=bounds && y>(1-limits)*imageHeight) y = imageHeight; /* To ignore annotation label at bottom */
					else if (tBBWidth<bounds){
						rightX = minOf(rightX,startX);
						y = maxOf(y,startY + tBBHeight);
					}
				}
			}
		}
		close();
		makeRectangle(leftX, topY, rightX-leftX, bottomY-topY);	
		if(startBM==false) setBatchMode("exit & display");
	}