rm -rf /tmp/SwiftNavigation
rsync -a ../SwiftNavigation --exclude=.build /tmp
p=/tmp/SwiftNavigation
rm -rf $p/Sources/CRecast/*cpp $p/Sources/CRecast/*h $p/Sources/CRecast/*/*.cpp $p/Sources/CRecast/*/*.h
echo 'void demo(); typedef unsigned int dtPolyRef;' > $p/Sources/CRecast/include/demo.h
echo 'void demo(){}' > $p/Sources/CRecast/demo.c
sed 's/.interoperabilityMode(.Cxx)//' < Package.swift > $p/Package.swift
for x in Sources/SwiftNavigation/*swift; do
    perl  docscripts/doc.pl $x | sed -e 's/rawValue: Int32(DT_STRAIGHTPATH[_A-Za-z]*.rawValue)/rawValue: 0/' -e 's/v: DT_STRAIGHTPATH_[_A-Z]*/rawValue: 0/' -e 's/value: DT_CROWD_[_A-Za-z]*/rawValue: 0/' > $p/$x
done
