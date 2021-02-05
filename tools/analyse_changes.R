library(ggplot2)
library(scales)
library(maditr)

# Note: I'm including sbk05 in changes.csv just in case. At least the way it's currently implemented, my method is unsuitable for sbk05.
# TODO: mention some percentages of how many variables were removed (the high points should sound impressive)

changes <- read.csv("../results/changes.csv", header = FALSE)
colnames(changes) <- c("instance", "encoding", "before_variables", "before_clauses", "after_variables", "after_clauses")

changes$dataset <- "Non-binary"
changes$dataset[grepl("DQMR", changes$instance, fixed = TRUE)] <- "DQMR"
changes$dataset[grepl("Grid", changes$instance, fixed = TRUE)] <- "Grid"
changes$dataset[grepl("mastermind", changes$instance, fixed = TRUE)] <- "Mastermind"
changes$dataset[grepl("blockmap", changes$instance, fixed = TRUE)] <- "Random Blocks"
changes$dataset[grepl("fs-", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("Plan_Recognition", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("students", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("tcc4f", changes$instance, fixed = TRUE)] <- "Other binary"

# Note: jitter is added because many data points have exactly the same before/after numbers
scatter <- function(data, x_var, y_var) {
  limits <- c(min(data[[x_var]], data[[y_var]], na.rm = TRUE), max(data[[x_var]], data[[y_var]], na.rm = TRUE))
  ggplot(data, aes(.data[[x_var]], .data[[y_var]], col = dataset)) +
#    geom_point() +
    geom_count() +
#    geom_jitter(width = 0.1, height = 0.1) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = limits) +
    scale_y_continuous(trans = log10_trans(), limits = limits) +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light()
}

# Before/after comparison of the number of variables
# Note: the same plot for other encodings looks very similar
scatter(changes[changes$encoding == "bklm16",], "before_variables", "after_variables")
scatter(changes[data$encoding == "bklm16",], "before_clauses", "after_clauses")

# Comparison of encodings after optimisation
df <- dcast(data = changes, formula = instance + dataset ~ encoding,
            fun.aggregate = NULL,
            value.var = c("before_variables", "before_clauses", "after_variables", "after_clauses"))

scatter(df, "after_variables_bklm16", "after_variables_cd06")
scatter(df, "after_variables_bklm16", "after_variables_cd05")
scatter(df, "after_variables_bklm16", "after_variables_d02")
scatter(df, "after_clauses_bklm16", "after_clauses_cd06")
scatter(df, "after_clauses_bklm16", "after_clauses_cd05")
scatter(df, "after_clauses_bklm16", "after_clauses_d02")
scatter(df, "after_variables_bklm16", "before_variables_sbk05")
scatter(df, "after_clauses_bklm16", "before_clauses_sbk05")

scatter(df, "before_variables_bklm16", "before_variables_cd06")
scatter(df, "before_variables_bklm16", "before_variables_cd05")
scatter(df, "before_variables_bklm16", "before_variables_d02")
scatter(df, "before_clauses_bklm16", "before_clauses_cd06")
scatter(df, "before_clauses_bklm16", "before_clauses_cd05")
scatter(df, "before_clauses_bklm16", "before_clauses_d02")
scatter(df, "before_variables_bklm16", "before_variables_sbk05")
scatter(df, "before_clauses_bklm16", "before_clauses_sbk05")

# grouped box plots
df2 <- melt(changes[changes$encoding != "sbk05",], id.vars = c("instance", "dataset", "encoding"), measure.vars = c("before_variables", "after_variables"))
df3 <- melt(changes[changes$encoding != "sbk05",], id.vars = c("instance", "dataset", "encoding"), measure.vars = c("before_clauses", "after_clauses"))
ggplot(df2, aes(encoding, value, fill = variable)) +
  geom_boxplot(outlier.shape = NA) +
  scale_y_continuous(limits = quantile(df2$value, c(0, 0.7)))
ggplot(df3, aes(encoding, value, fill = variable)) +
  geom_boxplot(outlier.shape = NA) +
  scale_y_continuous(limits = quantile(df2$value, c(0, 0.7)))

# number of variables vs. inference time: useless (at least so far)
# NOTE: data comes from analyse.R
data$instance <- sub("results/", "", data$instance)
df4 <- melt(changes, id.vars = c("instance", "dataset", "encoding"), measure.vars = c("before_variables", "after_variables"))
df4$encoding[df4$variable == "after_variables"] <- paste(df4$encoding[df4$variable == "after_variables"], "pp", sep = "")
df <- data[data$novelty == "new",] %>% left_join(df4, by = c("instance", "encoding"))

ggplot(df, aes(value, inference_time, col = dataset.y, shape = dataset.y)) + geom_point()
