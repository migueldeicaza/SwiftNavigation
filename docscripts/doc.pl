while (<>) {
    if (/func / || /init \(/ || / init\(/ || /public var .*{/ || /deinit/) {
	#print ("Starting new block: $_");
	if (/public/) {
	    $public = 1;
	    print;
	} else {
	    $public = 0;
	}
	($spc) = /([ \t]*)[a-zA-Z]/;
	if (! /{/) {
	    while (<>) {
		print;
		if (/{/) {
		    goto breakWhile;
		}
	    }
	  breakWhile:
	}
	if ($public == 1) {
	    print ($spc);
	    print ("    fatalError ();\n");
	}
	while (<>) {
	    #print ("SCAN: $_\n");
	    #if (/^$(spc)}/) { break }
	    if (/^$spc}/ || /^$spc]/) {
		#print ("FOUND\n");
		goto exLoop;
	    }
	}
      exLoop:
	#print ("COMPLETED\n");
	if ($public == 1){
	    print ("$spc}\n");
	}
    } elsif (/^[ \t]+var /) {
	#print ("// $_");
    } else {
	print;
    }
}
