# For developers to detect unreasonable calls in code to translate strings.
# both applies to the R and QML code of the analysis module.

library(potools)
library(cli)

checkStatus <- c()
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

# Get po/mo compiling error
e <- capture.output(tools::update_pkg_po("."))

if (length(e) > 0) {
  checkStatus <- c(checkStatus, 1)
  # Format data to make read friendly in Github CL
  rPoError <- as.data.frame(matrix(e, ncol=5, byrow=TRUE))[1:4]
  colnames(rPoError) <- c("Error_Location", "Error_Type", "Original_Gettext", "Translated_text")
  cli_alert_danger("some translation error found in po file")
  cli_h2("Please request translation maintainer or refer to following to resolve them:")
  print(t(rPoError))
}

if (nrow(rEmptyCalls) > 0) {
  checkStatus <- c(checkStatus, 1)
  cli_alert_danger("{nrow(rEmptyCalls)} empty gettext call(s) found")
  cli_h2("Please refer to following to resolve them:")
  print(rEmptyCalls, row.names = FALSE)
}

if (nrow(placeholderData) > 0) {
  checkStatus <- c(checkStatus, 1)
  cli_alert_danger("{nrow(placeholderData)} multiple placeholders without index found")
  cli_h2("Please refer to following to resolve them:")
  print(placeholderData, row.names = FALSE)
}

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
      Translation_call = grepl(pattern = "qsTr(|Id|anslate)\\(\".*\"\\)", readL[, 1]),
      Empty_call       = grepl(pattern = "qsTr(|Id|anslate)\\(\"\"\\)", readL[, 1])
    )
    
    qmlSrcData <- rbind(qmlSrcData, tempData)
  }
  
  qmlErrorCalls <- subset(qmlSrcData, qmlSrcData$Empty_call == 1, select = c(1:3))
  
  if (nrow(qmlErrorCalls) > 0) {
    checkStatus <- c(checkStatus, 1)
    cli_alert_danger("{nrow(qmlErrorCalls)} empty Qt translate call(s) found")
    cli_h2("Please refer to following to resolve them:")
    print(qmlErrorCalls, row.names = FALSE)
  } else {
    cli_alert_success("QML message check PASSED")
  }
}

if (length(checkStatus) > 0) {
  # failing github action,custom exit code to different from a system exit
  quit(status = 10)
} else {
  cli_alert_success("All i18n check PASSED")
}
