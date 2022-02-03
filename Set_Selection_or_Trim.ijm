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
	v211104 Updated stripKnownExtensionsFromString function    v211112: Again
	v211208 Added "select none" and "select all" so it can replace 2 menu items. Added auto, inverse and crop options. Added image width to default options and set as maximum selection width.
	v211209 Default width NUMERICAL sorting restored. List now includes selection width if selection exists. Crop-to option removed as it is not working as expected.
	v211209d	Adds tight bounding box option.
	v211221 Restored Restore Selection. v220110 Added selected height as width option  v220120 Restored crop to selection option
	v220202 If height cannot contain width-based aspect ration then the width will be set by the height and the aspect ratio.
	*/
macro "Set Selection or Trim" {
	macroL = "Set_Selection_or_Trim_v220202.ijm";
	delimiter = "|";
	prefsNameKey = "ascSetSelection.";
	prefsParaKey = prefsNameKey+"Parameters";
	prefsValKey = prefsNameKey+"Values";
	prefsPara = call("ij.Prefs.get", prefsParaKey, "None");
	prefsVal = "" + call("ij.Prefs.get", prefsValKey, "None");
	prefsParas = split(prefsPara,delimiter);
	prefsVals = split(prefsVal,delimiter);
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
	selName = "enter new name";
	getDimensions(imageWidth, imageHeight, channels, slices, frames);
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
	stdDims = newArray(128,256,384,512,768,1024,1280,2048,2304,3072,4096,imageWidth,imageHeight);
	if (selType>=0){
		getSelectionBounds(selX, selY, selWidth, selHeight);
		startX = selX;
		startY = selY;
		newW = round(selWidth);
		newH = round(selHeight);
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
	if(is("binary")) stdDims2 = newArray("entry", "fraction", "non-background", "trim");
	else  stdDims2 = newArray("entry", "fraction", "trim");
	fractW = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"fractW",0.33333));
	fractH = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"fractH",0.33333));
	startFractX = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"startFractX",(1-fractW)/2));
	startFractY = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"startFractY",(1-fractH)/2));
	trimR = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimR",0));
	trimL = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimL",0));
	trimT = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimT",0));
	trimB = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"trimB",0));
	rotS = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"rotS",0));
	selName = getPrefsFromParallelArrays(prefsParas,prefsVals,"selName",selName);
	addOverlay = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"addOverlay",false));
	addROI = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"addROI",false));
	saveSelection = getPrefsFromParallelArrays(prefsParas,prefsVals,"saveSelection",false);
	cropSelection = getPrefsFromParallelArrays(prefsParas,prefsVals,"cropSelection",false);
	lastSelectionPath = getPrefsFromParallelArrays(prefsParas,prefsVals,"selectionPath","None");
	/* End of Default/Previous value section */

	Dialog.create("Selection choices   \(" + macroL + "\)");
		if (selType>=0) selectionText = "original selection";
		else selectionText = "center of the image";
		selectionTypes = newArray("rectangle","oval","restore selection \(Ctrl+Shift+E\)", "all \(Ctrl+A\)", "auto \(bounding box\)", "tight bounding box");
		if (selType>=0) selectionTypes = Array.concat(selectionTypes, "existing within bounding box", "none \(Ctrl+Shift+A\)", "inverse");
		if(lastSelectionPath!="None") selectionTypes = Array.concat(selectionTypes,"restore last saved selection");
		if (objectsBounds){
			Dialog.addMessage("Object\(s\) bounding box: X1: " + BXpxsMin + ", Y1: " + BYpxsMin + ", Width: " + BWpxs + ", Height: " + BHpxs + ", Width-Height: " + WHDiff
			+ "\nBounding box overrides other options if selected");
			selectionTypes = Array.concat(selectionTypes,"bounding box");
		}
		iST = indexOfArray(selectionTypes,selTypeName,0);
		// Dialog.addCheckbox("Crop to selection \(Ctrl+Shift+Alt+X\)", false);
		Dialog.addRadioButtonGroup("Selection type \('restore' and auto options create selections and exit\):", selectionTypes, 3, 3, selectionTypes[iST]);
		if (objectsBounds){
			Dialog.addNumber("Selection width expansion if bounding box selected",0,0,6,"pixels");
			Dialog.addNumber("Selection height expansion if bounding box selected",0,0,6,"pixels");
		}
		Dialog.addMessage("Tight bounding box: Rectangular selection within the maximum extent of the background");
		Dialog.setInsets(3, 20, 3);
		Dialog.addNumber("Tight bounding box: Intensity tolerance:",0.01,3,4,"% \(will be slow for large values\)");
		Dialog.setInsets(3, 20, 3);
		Dialog.addNumber("Tight bounding box: Limits:",20,0,3,"% \(necessary for annotation bars\)");
		stdDimsF = Array.concat(stdDimsSt,stdDims2);
		stdDimsFL = lengthOf(stdDimsF);
		iDefDimsF = indexOfArray(stdDimsF, newW, stdDimsFL-1);
		buttonGroupTxt1 = "Selection width \(image width = " + imageWidth;
		if (selType>=0) buttonGroupTxt1 += " , original selection width = " + newW; 
		if (selType>=0) buttonGroupTxt1 += " , original selection height = " + newH; 
		buttonGroupTxt1 += "\):";
		if (iDefDimsF<stdDims.length) Dialog.addRadioButtonGroup(buttonGroupTxt1, stdDimsF, floor(stdDimsFL/9)+1, 9, stdDimsF[iDefDimsF]);
		else Dialog.addRadioButtonGroup("Fixed selection widths \(image width = " + imageWidth + ", image height = " + imageHeight + "\):", stdDimsF, floor(stdDimsFL/9)+1, 9, stdDimsF[iDefDimsF]);
		if (selType>=0) aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "selection", "entry");
		else aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "entry");
		Dialog.addMessage("For preset widths the new selection will be centered on the " + selectionText + ".\nThe 'entry', 'trim' and 'fraction' options also allow pixel coordinate location input.");
		iAR = indexOfArray(aspectRatios,selAR,1);
		Dialog.addRadioButtonGroup("Aspect ratio \(does not alter 'entry', 'fraction', 'trim' of 'non-background' widths\):", aspectRatios, 1, lengthOf(aspectRatios), aspectRatios[iAR]);
		orientations = newArray("landscape", "portrait");
		iOr = indexOfArray(orientations,orientation,0);
		Dialog.addRadioButtonGroup("Orientations:", orientations, 1, 2, orientations[iOr]);
		Dialog.addNumber("Selection rotation:",rotS,5,5,"degrees");
		Dialog.addString("Selection name:",selName,30);
		Dialog.addCheckbox("Add selection to overlay?", addOverlay);
		Dialog.addCheckbox("Add selection to ROI manager?", addROI);
		Dialog.addCheckbox("Save selection in image folder?", saveSelection);
		Dialog.addCheckbox("Crop to selection", cropSelection);
		Dialog.addMessage("Use the arrow keys or drag the selection to move the selection with the mouse after the \nmacro has completed.");
	Dialog.show();
	selTypeName = Dialog.getRadioButton();
	tBBTolerancePc = Dialog.getNumber();
	tBBLimitsPc = Dialog.getNumber();
	if(startsWith(selTypeName,"none") || startsWith(selTypeName,"restore selection") ||startsWith(selTypeName,"all") || startsWith(selTypeName,"auto") || startsWith(selTypeName,"inverse") || startsWith(selTypeName,"existing") || startsWith(selTypeName,"tight")){
		if (startsWith(selTypeName,"none")) run("Select None");
		if (startsWith(selTypeName,"restore selection")) run("Restore Selection");
		else if (startsWith(selTypeName,"all")) run("Select All");
		else if (startsWith(selTypeName,"auto")){
			run("Select None");
			run("Select Bounding Box (guess background color)");
		}
		else if (startsWith(selTypeName,"existing")) run("Select Bounding Box (guess background color)");
		else if (startsWith(selTypeName,"inverse")) run("Make Inverse");
		else if (startsWith(selTypeName,"tight")){
			showStatus("Finding tight bounding box");
			tightBoundingBox(tBBTolerancePc,tBBLimitsPc);
			showStatus("Found tight bounding box");
		}
		if (cropSelection && selectionType()>=0) run("Crop");
		exit;
	}
	if (objectsBounds){
		bBEnlX = Dialog.getNumber();
		bBEnlY = Dialog.getNumber();
	}
	if (selTypeName=="bounding box") makeRectangle(BXpxsMin-floor(bBEnlX/2), BYpxsMin-floor(bBEnlY/2), BWpxs+bBEnlX, BHpxs+bBEnlY);
	else if (selTypeName=="restore last selection"){
		run("Restore Selection");
		newSelType = selectionType();
	}
	else if (selTypeName=="restore last saved selection"){
		open(lastSelectionPath);
		newSelType = selectionType();
	}
	else {
		if (selTypeName=="oval") newSelType = 1;
		else newSelType = 0;
		selSelWidth = Dialog.getRadioButton();
		selAR = Dialog.getRadioButton();
		newOr = Dialog.getRadioButton();
		rotS = Dialog.getNumber();
		selName = Dialog.getString();
		if (selName=="") selName = "enter new name";
		addOverlay = Dialog.getCheckbox();
		addROI = Dialog.getCheckbox();
		saveSelection = Dialog.getCheckbox();
		cropSelection = Dialog.getCheckbox();
		if (selSelWidth =="fraction" || selSelWidth =="entry" || selSelWidth =="non-background" || selSelWidth=="trim" ) {
			if (selSelWidth =="fraction") {
				Dialog.create("Fraction of original image or selection dimensions");
					if (selType!=-1) Dialog.addMessage("Original selection type = " + selType);
					Dialog.addMessage("New selection type = " + newSelType);
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
					x = maxOf(0,round(selX + selWidth * startFractX));
					y = maxOf(0,round(selY + selHeight * startFractY));
					w = maxOf(1,round(selWidth * fractW));
					h = maxOf(1,round(selHeight * fractH));
					if (newSelType==0) makeRectangle(x, y, w, h);
					else makeOval(x, y, w, h);
				}
				else {
					x = maxOf(0,round(imageWidth * startFractX));
					y = maxOf(0,round(imageHeight * startFractY));
					w = maxOf(1,round(imageWidth * fractW));
					h = maxOf(1,round(imageHeight * fractH));
					if (newSelType==0) makeRectangle(x, y, w, h);
					else makeOval(x, y, w, h);
				}
			}
			else if (selSelWidth =="entry") {
				Dialog.create("Enter pixel values for new selection");
					Dialog.addNumber("Upper left X:", startX);
					Dialog.addNumber("Upper left Y:", startY);
					Dialog.addNumber("Width:", newW);
					Dialog.addNumber("Height:", newH);
				Dialog.show();
					startX = Dialog.getNumber;
					startY = Dialog.getNumber;
					newW = Dialog.getNumber;
					newH = Dialog.getNumber;
				if (newSelType==0) makeRectangle(startX, startY, newW, newH);
				else makeOval(startX, startY, newW, newH);
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
				Dialog.create("Select trim in pixels");
					Dialog.addNumber("Trim from right by:", trimR);
					Dialog.addNumber("Trim from left by:", trimL);
					Dialog.addNumber("Trim from top by:", trimT);
					Dialog.addNumber("Trim from bottom by:", trimB);
				Dialog.show();
					trimR = Dialog.getNumber;
					trimL = Dialog.getNumber;
					trimT = Dialog.getNumber;
					trimB = Dialog.getNumber;
				if (selType!=-1) {
					if (newSelType==0) makeRectangle(selX+trimL, selY+trimT, selWidth-(trimL+trimR), selHeight-(trimT+trimB));
					else makeOval(selX+trimL, selY+trimT, selWidth-(trimL+trimR), selHeight-(trimT+trimB));
				}
				else {
					if (newSelType==0) makeRectangle(trimL, trimT, imageWidth-(trimL+trimR), imageHeight-(trimT+trimB));
					else makeOval(trimL, trimT, imageWidth-(trimL+trimR), imageHeight-(trimT+trimB));
				}
			}
		}
		else {
			newSelWidth = parseFloat(selSelWidth);
			if (selAR=="1:1") aspectR = 1;
			else if (selAR=="4:3") {
				if (newOr=="landscape") aspectR = 4/3;
				else aspectR = 3/4;
			}
			else if (selAR=="golden") {
				goldenR = 1.61803398875;
				if (newOr=="landscape") aspectR = goldenR;
				else aspectR = 1/goldenR;
			}
			else if (selAR=="16:9") {
				if (newOr=="landscape") aspectR = 16/9;
				else aspectR = 9/16;
			}
			else if (selAR=="entry") {
				Dialog.create("Enter desired aspect ratio");
				Dialog.addNumber("Aspect Ratio", aspectR);
				Dialog.show();
				aspectR = Dialog.getNumber();	
			}
			else selAR = aspectR;
			if (newOr=="landscape") aspectR = minOf(aspectR, 1/aspectR);
			else aspectR = maxOf(aspectR, 1/aspectR);
			if (newSelWidth*aspectR<imageHeight) newSelHeight = minOf(imageHeight,newSelWidth * aspectR);
			else {
				newSelHeight = imageHeight;
				newSelWidth = newSelHeight/aspectR;
			}
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
			if (selName!="enter new name") Roi.setName(selName);
			roiManager("Add");
		}
		if(saveSelection){
			selectionPath = getDirectory("image");
			if (!File.isDirectory(selectionPath)) selectionPath = getDir("Choose a Directory to save the selection information in");
			name = getInfo("image.filename");
			if (name!="") fileName = stripKnownExtensionFromString(name);
			else fileName = File.nameWithoutExtension;
			if (name!="") fileName = stripKnownExtensionFromString(getTitle);
			if (name!="")	name = "Selection-" + getDateTimeCode();
			selectionPath += fileName + "_selection.roi";
			saveAs("selection", selectionPath);
		}
		else selectionPath = "None"; /* required for prefs */
		setSelectionsParasSt = "macroName|aspectR|fractW|fractH|startFractX|startFractY|iDefDimsF|newH|newW|selAR|selTypeName|newSelType|orientation|startX|startY|trimR|trimL|trimT|trimB|rotS|selName|addOverlay|addROI|saveSelection|cropSelection|selectionPath";
		/* string of parameters separated by | delimiter - make sure first entry is NOT a number to avoid NaN errors */
		setSelectionValues = newArray(macroL,aspectR,fractW,fractH,startFractX,startFractY,iDefDimsF,newH,newW,selAR,selTypeName,newSelType,orientation,startX,startY,trimR,trimL,trimT,trimB,rotS,selName,addOverlay,addROI,saveSelection,cropSelection,selectionPath);
		/* array of corresponding to parameter list (in the same order) */
		setSelectionValuesSt = arrayToString(setSelectionValues,"|");
		/* Create string of values from values array */
		call("ij.Prefs.set", prefsParaKey, setSelectionsParasSt);
		// print(setSelectionsParasSt);
		call("ij.Prefs.set", prefsValKey, setSelectionValuesSt);
		// print(setSelectionValuesSt);
	}
	getSelectionBounds(selX, selY, selWidth, selHeight);
	showStatus("X1: " + selX + ", Y1: " + selY + ", W: " + selWidth + ", H: " + selHeight + " selected");
	if (cropSelection && selectionType()>=0) run("Crop");
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
		/* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value */
		index = default;
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
		v210924: Tries to make sure string stays as string
		v211014: Adds some additional cleanup
		v211025: fixes multiple knowns issue
		v211101: Added ".Ext_" removal
		v211104: Restricts cleanup to end of string to reduce risk of corrupting path
		v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		*/
		string = "" + string;
		if (lastIndexOf(string, ".")>0 || lastIndexOf(string, "_lzw")>0) {
			knownExt = newArray("dsx", "DSX", "tif", "tiff", "TIF", "TIFF", "png", "PNG", "GIF", "gif", "jpg", "JPG", "jpeg", "JPEG", "jp2", "JP2", "txt", "TXT", "csv", "CSV","xlsx","XLSX","_"," ");
			kEL = lengthOf(knownExt);
			chanLabels = newArray("\(red\)","\(green\)","\(blue\)");
			unwantedSuffixes = newArray("_lzw"," ","  ", "__","--","_","-");
			uSL = lengthOf(unwantedSuffixes);
			for (i=0; i<kEL; i++) {
				for (j=0; j<3; j++){ /* Looking for channel-label-trapped extensions */
					ichanLabels = lastIndexOf(string, chanLabels[j]);
					if(ichanLabels>0){
						index = lastIndexOf(string, "." + knownExt[i]);
						if (ichanLabels>index && index>0) string = "" + substring(string, 0, index) + "_" + chanLabels[j];
						ichanLabels = lastIndexOf(string, chanLabels[j]);
						for (k=0; k<uSL; k++){
							index = lastIndexOf(string, unwantedSuffixes[k]);  /* common ASC suffix */
							if (ichanLabels>index && index>0) string = "" + substring(string, 0, index) + "_" + chanLabels[j];	
						}				
					}
				}
				index = lastIndexOf(string, "." + knownExt[i]);
				if (index>=(lengthOf(string)-(lengthOf(knownExt[i])+1)) && index>0) string = "" + substring(string, 0, index);
			}
		}
		unwantedSuffixes = newArray("_lzw"," ","  ", "__","--","_","-");
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(string);
			if (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
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