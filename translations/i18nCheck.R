# For developers to detect unreasonable calls in code to translate strings.
# both applies to the R and QML code of the analysis module.

library(potools)
library(cli)

checkStatus <- c()

msgErrorCheck <- function(msgData, warningMsg) {
  if (nrow(msgData) > 0) {
    checkStatus <<- c(checkStatus, 1)
    cli_h2("Please refer to following to resolve them:")
    cli_alert_danger(warningMsg)
    print(msgData, row.names = FALSE)
  }
}
# Generate pot meta data from .R
cli_h1("Check R translations:")
rPotData <- potools::get_message_data(dir = ".", verbose = TRUE)

# Get unreasonable usage of gettext from .R
placeholderData <- subset(rPotData,
                          grepl(pattern = "(.*%[#.+-\\d]*[aAdifeEgGosxX].*){2,}", msgid)  # match multiple placeholders > 2 times.
                          & !grepl(pattern = "%%", msgid) # such '90%%' cases in gettextf
                          |  grepl(pattern = "(.*%[#.+-\\d]*[aAdifeEgGosxX].*){3,}", msgid_plural), # match plural conditions (> 3 times?)
                          select = c("file", "call", "line_number"))
rEmptyCalls <- subset(rPotData,
                      grepl(pattern = "gettext(|f)\\(['\"]['\"]\\)", call),
                      select = c("file", "call", "line_number"))
templateMsgError <- subset(rPotData, grepl(pattern = "%\\d\\$", msgid)                                 # match all placeholders like %1$s
                           & (!grepl(pattern = "%1\\$", msgid) | grepl(pattern = "%[a-zA-Z]", msgid)), # match missing %1$ or %s is present
                           select = c("file", "call", "line_number"))
rErrorCalls <- subset(rPotData,
                      grepl(pattern = "^gettext\\(.*%.*\\)", call),   # match single % inside gettext()
                      select = c("file", "call", "line_number"))
rLinkEmbedded <- subset(rPotData,
                      grepl(pattern = "(http|https)://", msgid),
                      select = c("file", "call", "line_number"))

# Get po/mo compiling error of R, We customized the tools::checkPoFiles function
jaspCheckPoFiles <- function(dir) {
  files <- list.files(path = dir, pattern = "^R-.*[.]po$",
                      full.names = TRUE, recursive = TRUE)
  result <- matrix(character(), ncol = 5L, nrow = 0L)
  for (f in files) {
    errs <- tools::checkPoFile(f, strictPlural = startsWith(basename(f), "R-"))
    if (nrow(errs)) result <- rbind(result, errs)
  }
  
  return(result)
}

e <- jaspCheckPoFiles("./po")

rPoError <- data.frame()
if (length(e) > 1) {
  rPoError <- as.data.frame(e)
  colnames(rPoError) <- c("Error_Location", "References", "Error_Type", "Original_Gettext", "Translated_text")
}

msgErrorCheck(rPoError,         "Some translation errors found in po file.")
msgErrorCheck(rEmptyCalls,      "{nrow(rEmptyCalls)} empty gettext call(s) found.")
msgErrorCheck(placeholderData,  "{nrow(placeholderData)} multiple placeholders without index found.")
msgErrorCheck(templateMsgError, "There are numbering errors with multiple placeholders.")
msgErrorCheck(rErrorCalls,      "Don't use `gettext()` if `%` inside, but use `gettextf()` with `%%` instead.")
msgErrorCheck(rLinkEmbedded,    "Please don't pass the link directly inside translation call(s).")

if (length(checkStatus) == 0) {
  cli_alert_success("R message check PASSED")
}

cli_h1("Check QML translations:")
# Get QML files paths
qmlFiles <- list.files(path = file.path("inst", "qml"), pattern = "\\.qml", recursive = TRUE, full.names = TRUE)

if (length(qmlFiles) == 0) {
  cli_alert("No QML file found, maybe it's not a valid JASP module.")
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
      Empty_call       = grepl(pattern = "qsTr(|Id|anslate)\\((|['\"]['\"])\\)", readL[, 1]),  # match for empty qsTr(),qsTr(""),qsTr('') etc.
      Link_embedded    = grepl(pattern = "(http|https)://", readL[, 1]) & !grepl(pattern = "\\.arg\\([\"'].*(http|https)://", readL[, 1])
    )
    
    qmlSrcData <- rbind(qmlSrcData, tempData)
  }
  
  hasEmptyCall  <- qmlSrcData$Empty_call == TRUE
  hasLink       <- qmlSrcData$Translation_call & qmlSrcData$Link_embedded
  qmlErrorCalls <- subset(qmlSrcData, hasEmptyCall | hasLink, select = c(1:3))
  
  if (nrow(qmlErrorCalls) == 0) {
    cli_alert_success("QML message check PASSED")
  } else {
    if (any(hasEmptyCall))    cli_alert_danger("Please don't pass empty strings inside translation call(s).")
    if (any(hasLink))         cli_alert_danger("Please use `.arg()` to pass the link instead of pass it directly inside call(s).")
    msgErrorCheck(qmlErrorCalls, "{nrow(qmlErrorCalls)} not recommended Qt translate call(s) found.")
  }
}

if (length(checkStatus) > 0) {
  # failing github action,custom exit code to different from a system exit
  quit(status = 10)
} else {
  cli_alert_success("All i18n check PASSED")
}
