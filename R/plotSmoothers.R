
.plotSmoothers <- function(model, nPoints = 100, lwd = 2, size = 2/3,
                          xlab = "Pseudotime",
                          ylab = "Log(expression + 1)",
                          border = FALSE,
                          alpha = 1,
                          sample = 1)
{

  data <- model$model
  y <- data$y

  #construct time variable based on cell assignments.
  nCurves <- length(model$smooth)
  col <- timeAll <- rep(0, nrow(data))
  for (jj in seq_len(nCurves)) {
    for (ii in seq_len(nrow(data))) {
      if (data[ii, paste0("l", jj)] == 1) {
        timeAll[ii] <- data[ii, paste0("t", jj)]
        col[ii] <- jj
      } else {
        next
      }
    }
  }

  # plot raw data
  df <- data.frame("time" = timeAll,
                   "gene_count" = y,
                   "lineage" = as.character(col))
  rows <- sample(seq_len(nrow(df)), nrow(df) * sample, replace = FALSE)
  df <- df[rows, ]
  p <- ggplot(df, aes(x = time, y = log1p(gene_count), col = lineage)) +
    geom_point(size = size) +
    labs(x = xlab, y = ylab) +
    theme_classic() +
    scale_color_viridis_d(alpha = alpha)


  # predict and plot smoothers across the range
  for (jj in seq_len(nCurves)) {
    df <- .getPredictRangeDf(model$model, jj, nPoints = nPoints)
    yhat <- predict(model, newdata = df, type = "response")
    if (border) {
      p <- p +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj)),
                  lwd = lwd + 1, colour = "white") +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj)),
                  lwd = lwd)
    } else {
      p <- p +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj)),
                  lwd = lwd)
    }

  }
  return(p)
}



.plotSmoothers_sce <- function(models, counts, gene, nPoints = 100, lwd = 2,
                               size = 2/3, xlab = "Pseudotime",
                               ylab = "Log(expression + 1)", border = FALSE,
                               alpha = 2/3, sample = sample, pointCol = NULL)
{

  #input is singleCellExperiment object.

  if (length(gene) > 1) stop("Only provide a single gene's ID with the ",
                            "gene argument.")
  # check if all gene IDs provided are present in the models object.
  if (is(gene, "character")) {
    if (!all(gene %in% names(models))) {
      stop("The gene ID is not present in the models object.")
    }
    id <- which(names(models) %in% gene)
  } else id <- gene

  dm <- colData(models)$tradeSeq$dm # design matrix
  y <- unname(counts[id,])
  X <- colData(models)$tradeSeq$X # linear predictor
  slingshotColData <- colData(models)$slingshot
  pseudotime <- slingshotColData[,grep(x = colnames(slingshotColData),
                                       pattern = "pseudotime")]
  if (is.null(dim(pseudotime))) pseudotime <- matrix(pseudotime, ncol = 1)
  nCurves <- length(grep(x = colnames(dm), pattern = "t[1-9]"))
  betaMat <- rowData(models)$tradeSeq$beta[[1]]
  beta <- betaMat[id,]


  #construct time variable based on cell assignments.
  lcol <- timeAll <- rep(0, nrow(dm))
  for (jj in seq_len(nCurves)) {
    for (ii in seq_len(nrow(dm))) {
      if (dm[ii, paste0("l", jj)] == 1) {
        timeAll[ii] <- dm[ii, paste0("t", jj)]
        lcol[ii] <- jj
      } else {
        next
      }
    }
  }

  if(!is.null(pointCol)){
    if(length(pointCol) == 1){
      col <- colData(models)[,pointCol]
    } else if(length(pointCol) == ncol(models)){
      col <- pointCol
    } else {
      message(paste("pointCol should have length of either 1 or the number of cells,",
              "reverting to default color scheme."))
    }
  } else {
    col <- lcol
  }

  # plot raw data
  df <- data.frame("time" = timeAll,
                   "gene_count" = y,
                   "pCol" = as.character(col),
                   "lineage" = as.character(lcol))
  rows <- sample(seq_len(nrow(df)), nrow(df) * sample, replace = FALSE)
  df <- df[rows, ]
  if(is.null(pointCol)){
    p <- ggplot(df, aes(x = time, y = log1p(gene_count), col = lineage)) +
      geom_point(size = size) +
      labs(x = xlab, y = ylab) +
      theme_classic() +
      scale_color_viridis_d(alpha = alpha)
  } else {
    p <- ggplot(df, aes(x = time, y = log1p(gene_count), col = pCol)) +
      geom_point(size = size, alpha = alpha) +
      labs(x = xlab, y = ylab) +
      theme_classic() +
      scale_color_discrete() +
      labs(col = "Cell labels")
  }



  # predict and plot smoothers across the range
  for (jj in seq_len(nCurves)) {
    df <- .getPredictRangeDf(dm, jj, nPoints = nPoints)
    Xdf <- predictGAM(lpmatrix = X,
                      df = df,
                      pseudotime = pseudotime)
    yhat <-  c(exp(t(Xdf %*% t(beta)) + df$offset))
    if (border) {
      p <- p +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj),
                                    "pCol" = as.character(jj)),
                  lwd = lwd + 1, colour = "white") +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj),
                                    "pCol" = as.character(jj)),
                  lwd = lwd, col=viridis::viridis(nCurves)[jj])
    } else {
      p <- p +
        geom_line(data = data.frame("time" = df[, paste0("t", jj)],
                                    "gene_count" = yhat,
                                    "lineage" = as.character(jj),
                                    "pCol" = as.character(jj)),
                  lwd = lwd, col=viridis::viridis(nCurves)[jj])
    }

  }

  ## TODO: add legend for different lineages

  return(p)
}


#' @import mgcv
setOldClass("gam")

#' @description Plot the smoothers estimated by \code{tradeSeq}.
#' @param models Either the \code{SingleCellExperiment} object obtained after
#' running \code{fitGAM}, or the specific GAM model for the corresponding gene,
#' if working with the list output of \code{tradeSeq}.
#' @param counts The matrix of gene expression counts.
#' @param gene Gene name or row in count matrix of gene to plot.
#' @param nPoints The number of points used to extraplolate the fit.
#' Defaults to 100.
#' @param lwd Line width of the smoother. Passed to \code{\link{geom_line}}.
#' @param size Character expansion of the data points. Passed to \code{\link{geom_point}}.
#' @param xlab x-axis label. Passed to \code{\link{labs}}.
#' @param ylab y-axis label. Passed to \code{\link{labs}}.
#' @param border Logical: should a white border be drawn around the mean smoother.
#' @param alpha Numeric between 0 and 1, determines the transparancy of data points,
#' see \code{scale_color_viridis_d}.
#' @param sample Numeric between 0 and 1, use to subsample the cells when there
#' are too many so that it can plot faster.
#' @param pointCol Plotting colors for each cell. Can be either character vector of
#' length 1, denoting a variable in the \code{colData(models)} to color cells by,
#' or a vector of length equal to the number of cells.
#' @return A \code{\link{ggplot}} object
#' @examples
#' data(gamList, package = "tradeSeq")
#' plotSmoothers(gamList[[4]])
#' @import ggplot2
#' @import mgcv
#' @importFrom methods is
#' @rdname plotSmoothers
#' @export
setMethod(f = "plotSmoothers",
          signature = c(models = "gam"),
          definition = function(models,
                                nPoints = 100,
                                lwd = 2,
                                size = 2/3,
                                xlab = "Pseudotime",
                                ylab = "Log(expression + 1)",
                                border = TRUE,
                                alpha = 1,
                                sample = 1){

            .plotSmoothers(model = models,
                           nPoints = nPoints,
                           lwd = lwd,
                           size = size,
                           xlab = xlab,
                           ylab = ylab,
                           border = border,
                           alpha = alpha,
                           sample = sample)
          }
)

#' @rdname plotSmoothers
#' @import SingleCellExperiment
#' @export
setMethod(f = "plotSmoothers",
          signature = c(models = "SingleCellExperiment"),
          definition = function(models,
                                counts,
                                gene,
                                nPoints = 100,
                                lwd = 2,
                                size = 2/3,
                                xlab = "Pseudotime",
                                ylab = "Log(expression + 1)",
                                border = TRUE,
                                alpha = 1,
                                sample = 1,
                                pointCol = NULL){

            .plotSmoothers_sce(models = models,
                               counts = counts,
                               gene = gene,
                               nPoints = nPoints,
                               lwd = lwd,
                               size = size,
                               xlab = xlab,
                               ylab = ylab,
                               border = border,
                               alpha = alpha,
                               sample = sample,
                               pointCol = pointCol)
          }
)
