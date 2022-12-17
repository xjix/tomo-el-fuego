#!/bin/sh
# copy the named font into a mirror structure in the current directory
# good for translating fonts from linux to inferno
font_name="${1}"
for size in `9p ls "font/${font_name}"`; do
	echo "${size}"
	mkdir -p "${size}"
	for font_file in `9p ls "font/${font_name}/${size}"`; do
		echo "${size}/${font_file}"
		9p read "font/${font_name}/${size}/${font_file}" \
		> "${size}/${font_file}"
	done
done
