# For developers to detect unreasonable calls in code to translate strings.
# both applies to the R and QML code of the analysis module.

library(potools)
library(cli)

checkStatus <- c()

msgErrorCheck <- function(msgData, warningMsg) {
  if (nrow(msgData) > 0) {
    checkStatus <<- c(checkStatus, 1)
    cli_h2(warningMsg)
    cli_alert_danger("Please refer to following to resolve them:")
    print(msgData, row.names = FALSE)
  }
}
# Generate pot meta data from .R
cli_h1("Check R translations:")
rPotData <- potools::get_message_data(dir = ".", verbose = TRUE)

# Get unreasonable usage of gettext from .R
placeholderData <- subset(rPotData,
                          grepl(pattern = "(.*%[a-zA-Z].*|.*%[0-9]*[a-zA-Z].*){2,}", msgid)  # match multiple placeholders > 2 times.
                          & !grepl(pattern = "%%", msgid) # such '90%%' cases in gettextf
                          |  grepl(pattern = "(.*%[a-zA-Z].*|.*%[0-9]*[a-zA-Z].*){3,}", msgid_plural), # match plural conditions (> 3 times?)
                          select = c("file", "call", "line_number"))
rEmptyCalls <- subset(rPotData,
                      grepl(pattern = "gettext(|f)\\(['\"]['\"]\\)", call),
                      select = c("file", "call", "line_number"))
templateMsgError <- subset(rPotData, grepl(pattern = "%\\d\\$", msgid)                                 # match all placeholders like %1$s
                            & (!grepl(pattern = "%1\\$", msgid) | grepl(pattern = "%[a-zA-Z]", msgid)), # match missing %1$ or %s is present
                           select = c("file", "call", "line_number"))
rErrorCalls <- subset(rPotData,
                     grepl(pattern = "^gettext\\(.*%.*\\)", call),
                     select = c("file", "call", "line_number"))

# Get po/mo compiling error of R
e <- capture.output(tools::checkPoFiles("."))
rPoError <- as.data.frame(matrix(e, ncol=5, byrow=TRUE))[1:4]
colnames(rPoError) <- c("Error_Location", "Error_Type", "Original_Gettext", "Translated_text")

msgErrorCheck(rPoError,         "Some translation errors found in po file")
msgErrorCheck(rEmptyCalls,      "{nrow(rEmptyCalls)} empty gettext call(s) found")
msgErrorCheck(placeholderData,  "{nrow(placeholderData)} multiple placeholders without index found")
msgErrorCheck(templateMsgError, "There are numbering errors with multiple placeholders")
msgErrorCheck(rErrorCalls,      "Don't use `gettext()` if `%` inside, but use `gettextf()` with `%%` instead")

if (length(checkStatus) == 0) {
  cli_alert_success("R message check PASSED")
}

cli_h1("Check QML translations:")
# Get QML files paths
qmlFiles <- list.files(path = file.path("inst", "qml"), pattern = "\\.qml", recursive = TRUE, full.names = TRUE)

if (length(qmlFiles) == 0) {
  cli_alert("No QML file found")
} else {
  # Generate pot meta data from QML
  qmlSrcData <- data.frame()
  message("Getting QML-level messages...")
  
  for (i in 1:length(qmlFiles)) {
    filePaths <- paste0("./", qmlFiles[i])
    readL <- as.data.frame(readLines(filePaths, warn = FALSE))
    tempData <- data.frame(
      Source_file      = rep(filePaths),
      Call_code        = readL[, 1],
      Line_number      = 1:nrow(readL),
      Translation_call = grepl(pattern = "qsTr(|Id|anslate)\\(['\"].*['\"]\\)", readL[, 1]),  # match for qsTr, qsTranslate and qsTrId calls.
      Empty_call       = grepl(pattern = "qsTr(|Id|anslate)\\((|['\"]['\"])\\)", readL[, 1])  # match for empty qsTr(),qsTr(""),qsTr('') etc.
    )
    
    qmlSrcData <- rbind(qmlSrcData, tempData)
  }
  
  qmlErrorCalls <- subset(qmlSrcData, qmlSrcData$Empty_call == 1, select = c(1:3)) 
}

if (nrow(qmlErrorCalls) == 0) {
  cli_alert_success("QML message check PASSED")
} else {
  msgErrorCheck(qmlErrorCalls, "{nrow(qmlErrorCalls)} empty Qt translate call(s) found")
}

if (length(checkStatus) > 0) {
  # failing github action,custom exit code to different from a system exit
  quit(status = 10)
} else {
  cli_alert_success("All i18n check PASSED")
}
