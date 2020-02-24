/* Set selection at center of image or selection (if rectangle or oval), or as trim of image or selection
	v190227 1st version  Peter J. Lee  Applied Superconductivity Center, National High Magnetic Field Laboratory, Florida State University
	v190513 Added restore selection and preferences	in imageJ prefs (..\Users\username\.imagej\IJ_Prefs.txt).
	v190605 All options should now be working.
	v200207 Added new features, updated ASC functions, fixed missing selection path in prefs.
	v200224 Deactivated print debug lines  :-$
	*/
macro "setSelection" {
	delimiter = "|";
	prefsNameKey = "ascSetSelection.";
	prefsParaKey = prefsNameKey+"Parameters";
	prefsValKey = prefsNameKey+"Values";
	prefsPara = call("ij.Prefs.get", prefsParaKey, "None");
	macroName = File.getName(getInfo("macro.filepath"));
	prefsVal = "" + call("ij.Prefs.get", prefsValKey, "None");
	prefsParas = split(prefsPara,delimiter);
	prefsVals = split(prefsVal,delimiter);
	if (prefsParas.length!=prefsVals.length) {
		Dialog.create("Prefs mismatch");
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
	selType = selectionType();
	/* Provide default or previous values */
	stdDims = newArray(256,384,512,768,1024,1280,2048,2304,3072,4096);
	for (i=0; i<stdDims.length; i++) if(imageWidth<stdDims[i] && imageHeight<stdDims[i]) stdDims = Array.trim(stdDims,i);
	if (selType==0 || selType==1){
		getSelectionBounds(selX, selY, selWidth, selHeight);
		startX = selX;
		startY = selY;
		newW = round(selWidth);
		newH = round(selHeight);
		oldSelName = selectionName;
		if (oldSelName!="") selName = oldSelName;
		run("Select None");
		if (selType==0) selTypeName = "rectangle";
		else (selType==1) selTypeName = "oval";
	}
	else {
		selTypeName = getPrefsFromParallelArrays(prefsParas,prefsVals,"selTypeName","rectangle");
		startX = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"startX",0));
		startY = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"startY",0));
		newH = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"newH",imageHeight));
		newW = parseInt(getPrefsFromParallelArrays(prefsParas,prefsVals,"newW",imageWidth));
	}
	aspectR = parseFloat(getPrefsFromParallelArrays(prefsParas,prefsVals,"aspectR",newW/newH));
	selAR = getPrefsFromParallelArrays(prefsParas,prefsVals,"selAR","4:3");
	if (aspectR>=1) orientation = getPrefsFromParallelArrays(prefsParas,prefsVals,"orientation","landscape");
	else orientation = getPrefsFromParallelArrays(prefsParas,prefsVals,"orientation","portrait");
	if ((indexOfArray(stdDims, newW, -1))<0) stdDims = Array.concat(stdDims,newW);
	if ((indexOfArray(stdDims, newH, -1))<0) stdDims = Array.concat(stdDims,newH);
	stdDims = Array.sort(stdDims);
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
	lastSelectionPath = getPrefsFromParallelArrays(prefsParas,prefsVals,"selectionPath","None");
	/* End of Default/Previous value section */

	Dialog.create(macroName + ": Selection choices");
		if (selType!=-1) selectionText = "original selection";
		else selectionText = "center of the image";
		Dialog.addMessage("For preset widths the new selection will be centered on the " + selectionText + ".\nUse the arrow keys or drag the selection to move the selection with the mouse \nafter the macro has completed.\nThe 'entry', 'trim' and 'fraction' options also allow pixel coordinate location input.");
		if(lastSelectionPath=="None") selectionTypes = newArray("rectangle","oval","restore last selection");
		else selectionTypes = newArray("rectangle","oval","restore last selection","restore last saved selection");
		iST = indexOfArray(selectionTypes,selTypeName,0);
		Dialog.addRadioButtonGroup("Selection type \('restore' options restore selections and exit\):", selectionTypes, 2, 2, selectionTypes[iST]);
		stdDimsF = Array.concat(stdDims,stdDims2);
		iDefDimsF = indexOfArray(stdDimsF, newW, lengthOf(stdDimsF)-1);
		if (iDefDimsF<stdDims.length) Dialog.addRadioButtonGroup("Selection width:", stdDimsF, 2, 5, d2s(stdDimsF[iDefDimsF],1));
		else Dialog.addRadioButtonGroup("Selection width:", stdDimsF, 2, 5, stdDimsF[iDefDimsF]);
		if (selType>=0) aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "selection", "entry");
		else aspectRatios = newArray("1:1", "4:3", "golden", "16:9", "entry");
		iAR = indexOfArray(aspectRatios,selAR,1);
		Dialog.addRadioButtonGroup("Aspect ratio \(does not alter 'entry', 'fraction', 'trim' of 'non-background' widths\):", aspectRatios, 1, 5, aspectRatios[iAR]);
		orientations = newArray("landscape", "portrait");
		iOr = indexOfArray(orientations,orientation,0);
		Dialog.addRadioButtonGroup("Orientations:", orientations, 1, 2, orientations[iOr]);
		Dialog.addNumber("Selection rotation:",rotS,5,5,"degrees");
		Dialog.addString("Selection name:",selName,12);
		Dialog.addCheckbox("Add selection to overlay?", addOverlay);
		Dialog.addCheckbox("Add selection to ROI manager?", addROI);
		Dialog.addCheckbox("Save selection in image folder?", saveSelection);
	Dialog.show();
	selTypeName = Dialog.getRadioButton();
	if (selTypeName=="restore last selection"){
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
			newSelHeight = minOf(imageHeight,newSelWidth * aspectR);
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
			path = getDirectory("image");
			if (path=="") exit ("path not available");
			name = getInfo("image.filename");
			if (name=="") exit ("name not available");
			name = stripKnownExtensionFromString(name);
			selectionPath = path + name + "_selection.roi";
			saveAs("selection", selectionPath);
		}
		else selectionPath = "None"; /* required for prefs */
		setSelectionsParasSt = "macroName|aspectR|fractW|fractH|startFractX|startFractY|iDefDimsF|newH|newW|selAR|selTypeName|newSelType|orientation|startX|startY|trimR|trimL|trimT|trimB|rotS|selName|addOverlay|addROI|saveSelection|selectionPath";
		/* string of parameters separated by | delimiter - make sure first entry is NOT a number to avoid NaN errors */
		setSelectionValues = newArray(macroName,aspectR,fractW,fractH,startFractX,startFractY,iDefDimsF,newH,newW,selAR,selTypeName,newSelType,orientation,startX,startY,trimR,trimL,trimT,trimB,rotS,selName,addOverlay,addROI,saveSelection,selectionPath);
		/* array of corresponding to parameter list (in the same order) */
		setSelectionValuesSt = arrayToString(setSelectionValues,"|");
		/* Create string of values from values array */
		call("ij.Prefs.set", prefsParaKey, setSelectionsParasSt);
		// print(setSelectionsParasSt);
		call("ij.Prefs.set", prefsValKey, setSelectionValuesSt);
		// print(setSelectionValuesSt);
	}
	showStatus("setSelection completed");
	run("Collect Garbage");
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
		if (lastIndexOf(string, ".")!=-1) {
			knownExt = newArray("tif", "tiff", "TIF", "TIFF", "png", "PNG", "GIF", "gif", "jpg", "JPG", "jpeg", "JPEG", "jp2", "JP2", "txt", "TXT", "csv", "CSV");
			for (i=0; i<knownExt.length; i++) {
				index = lastIndexOf(string, "." + knownExt[i]);
				if (index>=(lengthOf(string)-(lengthOf(knownExt[i])+1))) string = substring(string, 0, index);
			}
		}
		return string;
	}