#!/bin/bash

cd $(dirname $0)

echo $PWD
configuration=Release
projectName=luacocoa

for scheme in libffi-iOS luaoc; do
    xcodebuild                                                      \
        -workspace luacocoa.xcworkspace                             \
        -scheme $scheme                                             \
        -destination 'platform=iOS Simulator,name=iPhone 5'         \
        -destination 'generic/platform=iOS'                         \
        -configuration $configuration                               \
        SYMROOT="$PWD/build"                                        \
        ;
done

if (($? == 0)); then
    echo "create universal libs"

    cd build
    if [[ ! -d $projectName ]] ; then
        mkdir $projectName
    fi

    for lib in $(cd $configuration-iphoneos; ls *.a); do
        echo "create universal lib $lib"
        lipo -create -output $projectName/"$lib" \
            $configuration-iphoneos/"$lib" $configuration-iphonesimulator/"$lib"
    done

    cp -r $configuration-iphoneos/include $projectName

    echo "create universal libs done!"
fi
