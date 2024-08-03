#!/bin/bash

debug="false"
debug_printf() 
{
	if [ ! ${debug} == "false" ]; then
		printf "$@"
	fi
}

ROOT=${1-.}
if [ "${ROOT}" == '.' ]; then
	ROOT=$(pwd)
fi

DESCRIPTION_QML="${ROOT}/inst/Description.qml"
NAMESPACE="${ROOT}/NAMESPACE"
HELP_FILES_DIR="${ROOT}/inst/help"
QML_FILES_DIR="${ROOT}/inst/qml"

debug_printf "root = %s\n" $ROOT
debug_printf "DESCRIPTION_QML = %s\n" $DESCRIPTION_QML

# FUNCTIONS=$(sed -n 's/\s*func\s*:\s*\"\(.*\)\"/\1/p' "${DESCRIPTION_QML}")
FUNCTIONS=$(sed -n 's/.*func\s*:\s*\"\(.*\)\".*/\1/p' "${DESCRIPTION_QML}")
printf 'found functions:\n%s' "${FUNCTIONS}"
printf '\n'

declare -a R_EXPORTS_MISSING
declare -a HELP_FILES_BAD_CAPITALIZATION
declare -a QML_FILES_BAD_CAPITALIZATION

for FUN in ${FUNCTIONS}
do

	debug_printf "function %s\n" "${FUN}"

	R_FUNCTION=$(sed -n "/export(${FUN})/p" ${NAMESPACE})
	if [ "${R_FUNCTION}" != "export(${FUN})" ]; then
		R_EXPORTS_MISSING+=("${FUN}")
	fi

	if [ -d "${HELP_FILES_DIR}" ]; then 

		HELPFILE_CASE_SENSITIVE=$(ls "${HELP_FILES_DIR}"   | grep               "^${FUN}\(\.md\|\.html\)$" | head -n 1)
		HELPFILE_CASE_INSENSITIVE=$(ls "${HELP_FILES_DIR}" | grep --ignore-case "^${FUN}\(\.md\|\.html\)$" | head -n 1)

		debug_printf "helpfile: case_sensitive = \"%s\" | case_insensitive = \"%s\"\n" "$HELPFILE_CASE_SENSITIVE" "$HELPFILE_CASE_INSENSITIVE"

		# only throw an error if there is no helpfile
		if [ "${HELPFILE_CASE_SENSITIVE}" == '' ] && [ "${HELPFILE_CASE_INSENSITIVE}" != '' ]; then
			debug_printf "adding %s to HELP_FILES_BAD_CAPITALIZATION\n" "${HELPFILE_CASE_INSENSITIVE}"
			HELP_FILES_BAD_CAPITALIZATION+=("${HELPFILE_CASE_INSENSITIVE}")
		fi

	fi

	QMLFILE_CASE_SENSITIVE=$(ls "${QML_FILES_DIR}"   | grep               "^${FUN}\.qml$" | head -n 1)
	QMLFILE_CASE_INSENSITIVE=$(ls "${QML_FILES_DIR}" | grep --ignore-case "^${FUN}\.qml$" | head -n 1)
	debug_printf "qml: case_sensitive = \"%s\" | case_insensitive = \"%s\"\n" "$QMLFILE_CASE_SENSITIVE" "$QMLFILE_CASE_INSENSITIVE"
	
	# always throw an error if the qml file is missing
	if [ "${QMLFILE_CASE_SENSITIVE}" == '' ]; then
	
		debug_printf "adding %s to QML_FILES_BAD_CAPITALIZATION\n" "${QMLFILE_CASE_INSENSITIVE}"
		# vary message depending on wether there is a case-insensitive qml file or not.
		if [ "${QMLFILE_CASE_INSENSITIVE}" == '' ]; then
			QML_FILES_BAD_CAPITALIZATION+=("${FUN}.qml")
		else
			QML_FILES_BAD_CAPITALIZATION+=("${QMLFILE_CASE_INSENSITIVE} should be ${FUN}.qml")
		fi
	fi


done

EXITCODE=0

if [ ${#R_EXPORTS_MISSING[@]} -gt 0 ]; then
	printf "These exports are missing in the NAMESPACE:\n"
	printf "\texport(%s)\n" "${R_EXPORTS_MISSING[@]}"
	printf "\n"
	EXITCODE=$((EXITCODE + 1))
fi

if [ ${#HELP_FILES_BAD_CAPITALIZATION[@]} -gt 0 ]; then
	printf "These helpfiles have incorrect capitalization:\n"
	printf "\t%s\n" "${HELP_FILES_BAD_CAPITALIZATION[@]}"
	printf "\n"
	EXITCODE=$((EXITCODE + 2))
fi

if [ ${#QML_FILES_BAD_CAPITALIZATION[@]} -gt 0 ]; then
	printf "These qml files are missing or have incorrect capitalization:\n"
	printf "\t%s\n" "${QML_FILES_BAD_CAPITALIZATION[@]}"
	printf "\n"
	EXITCODE=$((EXITCODE + 4))
fi

echo "EXITCODE = ${EXITCODE}"
exit ${EXITCODE}
#0: success
#1: missing R exports
#2: helpfiles with incorrect capitalization
#3: missing R exports + helpfiles with incorrect capitalization
#4: missing qml file (or incorrect capitalization)
#5: missing R exports + missing qml file (or incorrect capitalization)
#6: helpfiles with incorrect capitalization + missing qml file (or incorrect capitalization)
#7: missing R exports + helpfiles with incorrect capitalization + missing qml file (or incorrect capitalization)

