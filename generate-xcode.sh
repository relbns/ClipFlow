#!/bin/bash
echo "Generating Xcode project from Package.swift..."
swift package generate-xcodeproj
echo "Done! Open ClipFlow.xcodeproj"
