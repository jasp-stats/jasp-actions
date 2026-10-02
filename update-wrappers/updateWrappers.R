# Regenerates the R wrappers (R/<analysis>Wrapper.R) of a JASP module from its QML forms, and their help files (man/*.Rd).
#
# Usage: Rscript updateWrappers.R [moduleDir]
#
# Needs jaspSyntax and roxygen2. The module's own dependencies are not needed: roxygen runs on a throwaway package
# that only holds the wrapper files, so the module code is never loaded.
#
# jaspSyntax is only called in child R processes, one per analysis. Creating several analysis forms in one process
# can crash in the QML garbage collector (seen on Linux with jaspDescriptives), and some modules crash R when it
# exits. A child reports through a result file, so a crash after the wrapper is written does not count as a failure.

rscript <- file.path(R.home("bin"), "Rscript")

# Runs `code` in a child R process; `code` can write its result to the file named by `resultFile`.
runBridge <- function(code) {
  resultFile <- tempfile("result")
  script     <- tempfile("bridge", fileext = ".R")
  writeLines(c(sprintf("resultFile <- %s", deparse(resultFile)), code), script)

  output <- suppressWarnings(system2(rscript, shQuote(script), stdout = TRUE, stderr = TRUE))
  status <- attr(output, "status")

  list(
    output = output,
    status = if (is.null(status)) 0L else status,
    result = if (file.exists(resultFile)) readLines(resultFile, warn = FALSE) else NULL
  )
}

showOutput <- function(run) {
  noise <- "GridLayout is too large|Binding loop detected|TabBar.qml"
  message(paste(utils::tail(grep(noise, run[["output"]], value = TRUE, invert = TRUE), 30L), collapse = "\n"))
}

args      <- commandArgs(trailingOnly = TRUE)
moduleDir <- normalizePath(if (length(args) > 0L) args[[1L]] else ".", mustWork = TRUE)

descriptionFile <- file.path(moduleDir, "DESCRIPTION")
if (!file.exists(descriptionFile))
  stop("No DESCRIPTION file in ", moduleDir, ": this is not an R package.")

description <- read.dcf(descriptionFile)
packageName <- unname(description[1L, "Package"])

if (!file.exists(file.path(moduleDir, "inst", "Description.qml"))) {
  message("No inst/Description.qml in ", moduleDir, ": this is not a JASP module, nothing to do.")
  quit(save = "no", status = 0L)
}

# The generator names the module after the directory (it writes `<module>::<analysis>` and
# `jaspBase::runWrappedAnalysis("<module>", ...)`), so make sure that directory is called after the package.
modulePath <- moduleDir
if (basename(moduleDir) != packageName) {
  modulePath <- file.path(tempfile("module"), packageName)
  dir.create(dirname(modulePath))
  if (!file.symlink(moduleDir, modulePath))
    stop("Could not link ", moduleDir, " as ", modulePath)
}

run <- runBridge(sprintf(paste(
  "info <- jaspSyntax::parseDescription(%s)",
  "analyses <- vapply(info[['analyses']], function(analysis) analysis[['name']], character(1L))",
  "writeLines(c(as.character(isTRUE(info[['hasWrappers']])), analyses), resultFile)",
  sep = "\n"), deparse(modulePath)))
if (is.null(run[["result"]])) {
  showOutput(run)
  stop("Reading inst/Description.qml of ", packageName, " failed (exit status ", run[["status"]], ").")
}
if (run[["result"]][[1L]] != "TRUE") {
  message(packageName, " does not set hasWrappers in inst/Description.qml, nothing to do.")
  quit(save = "no", status = 0L)
}
analyses <- run[["result"]][-1L]

rDir             <- file.path(moduleDir, "R")
existingWrappers <- list.files(rDir, pattern = "Wrapper\\.R$")

failed <- character()
for (analysis in analyses) {
  run <- runBridge(sprintf(
    "writeLines(jaspSyntax::generateAnalysisWrapper(%s, %s), resultFile)", deparse(modulePath), deparse(analysis)))
  result <- paste(run[["result"]], collapse = " ")

  if (startsWith(result, "Wrapper generated")) {
    message(result, if (run[["status"]] != 0L) sprintf(" (R then exited with status %d, ignored)", run[["status"]]))
  } else {
    showOutput(run)
    message("Generating the wrapper of ", analysis, " failed (exit status ", run[["status"]], "): ", result)
    failed <- c(failed, analysis)
  }
}
if (length(failed) > 0L)
  stop("Generating the wrappers of ", packageName, " failed for: ", paste(failed, collapse = ", "))

# The generator writes R/<analysis>Wrapper.R, but older wrappers may differ in case (e.g. ttestonesampleWrapper.R).
# A case-insensitive file system (macOS) writes into the existing file; on Linux both would exist and define the
# analysis twice, so move the generated code into the existing file.
for (analysis in analyses) {
  generated <- paste0(analysis, "Wrapper.R")
  existing  <- existingWrappers[tolower(existingWrappers) == tolower(generated) & existingWrappers != generated]
  if (length(existing) == 1L && generated %in% list.files(rDir) && existing %in% list.files(rDir)) {
    file.copy(file.path(rDir, generated), file.path(rDir, existing), overwrite = TRUE)
    file.remove(file.path(rDir, generated))
  }
}

wrapperFiles <- list.files(file.path(moduleDir, "R"), pattern = "Wrapper\\.R$", full.names = TRUE)
message("Generated ", length(wrapperFiles), " wrapper(s) for ", packageName)

# Build the help files on a copy holding only the wrappers, so roxygen does not need the module's dependencies,
# leaves DESCRIPTION and NAMESPACE alone, and does not touch help files that are not generated from wrappers.
rdPackage <- file.path(tempfile("rd"), packageName)
dir.create(file.path(rdPackage, "R"), recursive = TRUE)
invisible(file.copy(wrapperFiles, file.path(rdPackage, "R")))

rdDescription <- c(Package = packageName, Title = packageName, Version = "0.0.0", Description = packageName, License = "GPL (>= 2)")
for (field in intersect(c("Title", "Version", "Description", "License", "Encoding", "Roxygen"), colnames(description)))
  rdDescription[[field]] <- description[1L, field]
write.dcf(t(rdDescription), file.path(rdPackage, "DESCRIPTION"))

roxygen2::roxygenise(rdPackage, roclets = "rd", load_code = "source")

rdFiles <- list.files(file.path(rdPackage, "man"), pattern = "\\.Rd$", full.names = TRUE)
dir.create(file.path(moduleDir, "man"), showWarnings = FALSE)
invisible(file.copy(rdFiles, file.path(moduleDir, "man"), overwrite = TRUE))
message("Generated ", length(rdFiles), " help file(s) for ", packageName)
