# For developers to detect unreasonable calls in code to translate strings.
# both applies to the R and QML code of the analysis module.

library(potools)
library(cli)

checkStatus <- c()
# Generate pot meta data from .R
cli_h1("Check R translations:")
rPotData <- potools::get_message_data(dir = ".",verbose = TRUE)

# Get wrong usage of gettext from .R
rErrorCalls <- subset(rPotData, rPotData$msgid=="", select = c("file", "call", "line_number"))
          
if (nrow(rErrorCalls) > 0) {
  checkStatus <- c(checkStatus, 1)
  # Warning in CLI
  cli_alert_danger("{nrow(rErrorCalls)} empty gettext call(s) found")
  cli_h2("Please refer to following to resolve them:")
  print.data.frame(rErrorCalls, row.names = FALSE)
  }else{
    cli_alert_success("R message check PASSED")
} 

cli_h1("Check QML translations:")
# Get QML files paths
qmlFiles <- as.list(list.files(path = ".", pattern = ".qml", recursive = T))

if (length(qmlFiles) == 0) {
  cli_alert("No QML file found")
  } else {
  # Generate pot meta data from QML
  qmlSrcData <- data.frame()
  message("Getting QML-leve messages...")

  for (i in 1:length(qmlFiles)) {
    filePaths <- paste0("./", qmlFiles[[i]])
    readL     <- as.data.frame(readLines(filePaths, warn = FALSE))
    tempData  <- data.frame(
      Source_file      = rep(filePaths), 
      Call_code        = readL[,1], 
      Line_number      = 1:nrow(readL),
      Translation_call = grepl(pattern="qsTr(|Id|anslate)\\(\".*\"\\)", readL[,1])+0,
      Empty_call       = grepl(pattern="qsTr(|Id|anslate)\\(\"*\"\\)", readL[,1])+0)

    qmlSrcData <- rbind(qmlSrcData, tempData)
  }

  qmlErrorCalls <- subset(qmlSrcData, qmlSrcData$Empty_call == 1, select = c(1:3))

  if (nrow(qmlErrorCalls) > 0) {
    checkStatus <- c(checkStatus, 1)
    cli_alert_danger("{nrow(qmlErrorCalls)} empty Qt translate call(s) found")
    cli_h2("Please refer to following to resolve them:")
    print.data.frame(qmlErrorCalls, row.names = FALSE)
  } else {
    cli_alert_success("QML message check PASSED")
  }
} 

if (length(checkStatus) > 0){
  # failing github action,custom exit code to different from a system exit
  quit(status = 10)
} else{
  cli_alert_success("All i18n check PASSED")
}
