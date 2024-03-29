library(ggplot2)
library(scales)
library(maditr)
library(tikzDevice)

changes <- read.csv("../results/changes.csv", header = FALSE)
colnames(changes) <- c("instance", "encoding", "before_variables", "before_clauses", "after_variables", "after_clauses")
changes$after_variables[changes$encoding == "sbk05"] <- NA

changes$dataset <- "Non-binary"
changes$dataset[grepl("DQMR", changes$instance, fixed = TRUE)] <- "DQMR"
changes$dataset[grepl("Grid", changes$instance, fixed = TRUE)] <- "Grid"
changes$dataset[grepl("mastermind", changes$instance, fixed = TRUE)] <- "Mastermind"
changes$dataset[grepl("blockmap", changes$instance, fixed = TRUE)] <- "Random Blocks"
changes$dataset[grepl("fs-", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("Plan_Recognition", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("students", changes$instance, fixed = TRUE)] <- "Other binary"
changes$dataset[grepl("tcc4f", changes$instance, fixed = TRUE)] <- "Other binary"

# Note: count is used because many data points have exactly the same before/after numbers
scatter <- function(data, x_var, y_var) {
  limits <- c(min(data[[x_var]], data[[y_var]], na.rm = TRUE), max(data[[x_var]], data[[y_var]], na.rm = TRUE))
  ggplot(data, aes(.data[[x_var]], .data[[y_var]], col = dataset)) +
    geom_count(alpha = 0.5) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = limits) +
    scale_y_continuous(trans = log10_trans(), limits = limits) +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light() +
    theme(legend.position = "right", legend.box = "vertical") +
    scale_color_brewer(palette = "Dark2") +
    xlab("\\texttt{bklm16} variables") +
    ylab("\\texttt{bklm16++} variables") +
    labs(color = "", size = "")
#    guides(color = guide_legend(ncol = 2), size = guide_legend(ncol = 2))
}

# Before/after comparison of the number of variables
# Note: the same plot for other encodings looks very similar
scatter(changes[changes$encoding == "bklm16",], "before_clauses", "after_clauses")

scatter(changes[changes$encoding == "d02",], "before_variables", "after_variables")
scatter(changes[changes$encoding == "d02",], "before_clauses", "after_clauses")

# Comparison of encodings after optimisation
changes.df <- dcast(data = changes, formula = instance + dataset ~ encoding,
            fun.aggregate = NULL,
            value.var = c("before_variables", "before_clauses", "after_variables", "after_clauses"))

changes.df %>% group_by(changes.df$dataset) %>% tally()

scatter(changes.df, "after_variables_bklm16", "after_variables_cd06")
scatter(changes.df, "after_variables_bklm16", "after_variables_cd05")
scatter(changes.df, "after_variables_bklm16", "after_variables_d02")
scatter(changes.df, "after_clauses_bklm16", "after_clauses_cd06")
scatter(changes.df, "after_clauses_bklm16", "after_clauses_cd05")
scatter(changes.df, "after_clauses_bklm16", "after_clauses_d02")
scatter(changes.df, "after_variables_bklm16", "before_variables_sbk05")
scatter(changes.df, "after_clauses_bklm16", "before_clauses_sbk05")

scatter(changes.df, "before_variables_bklm16", "before_variables_cd06")
scatter(changes.df, "before_variables_bklm16", "before_variables_cd05")
scatter(changes.df, "before_variables_bklm16", "before_variables_d02")
scatter(changes.df, "before_clauses_bklm16", "before_clauses_cd06")
scatter(changes.df, "before_clauses_bklm16", "before_clauses_cd05")
scatter(changes.df, "before_clauses_bklm16", "before_clauses_d02")
scatter(changes.df, "before_variables_bklm16", "before_variables_sbk05")
scatter(changes.df, "before_clauses_bklm16", "before_clauses_sbk05")

# grouped box plots
df2 <- melt(changes, id.vars = c("instance", "dataset", "encoding"),
            measure.vars = c("before_variables", "after_variables"))
df2$variable <- ifelse(df2$variabl == "before_variables", "before", "after")
df2$variable <- as.factor(df2$variable)
df2$variable <- factor(df2$variable, levels = rev(levels(df2$variable)))
df2$encoding <- paste0("\\texttt{", df2$encoding, "}")

#tikz(file = "../doc/SAT_paper/box.tex", width = 2.4, height = 2, standAlone = TRUE)
#tikz(file = "../doc/SAT_long_talk/box.tex", width = 2.5, height = 3.1, standAlone = TRUE)
tikz(file = "../../../annual-report/thesis/chapters/wmc_without_parameters/box.tex",
     width = 5.7, height = 3.1, standAlone = TRUE)
ggplot(df2, aes(encoding, value, fill = variable)) +
  geom_boxplot(outlier.shape = NA) +
  theme_light(base_size = 9) +
  scale_fill_brewer(palette = "Dark2") +
  xlab("") +
  ylab("Variables") +
  labs(fill = "") +
  coord_cartesian(ylim = quantile(df2$value, c(0, 0.8), na.rm = TRUE)) +
  theme(legend.position = "bottom", legend.margin = margin(t = -0.8, unit = 'cm'))
dev.off()

tikz(file = "../doc/SAT_paper/variable_scatter.tex", width = 3.2, height = 2.9)
scatter(changes[changes$encoding == "bklm16",], "before_variables", "after_variables")
dev.off()

df3 <- melt(changes[changes$encoding != "sbk05",], id.vars = c("instance", "dataset", "encoding"), measure.vars = c("before_clauses", "after_clauses"))
ggplot(df3, aes(encoding, value, fill = variable)) +
  geom_boxplot(outlier.shape = NA) +
  scale_y_continuous(limits = quantile(df2$value, c(0, 0.7)))

# number of variables vs. inference time: useless (at least so far)
# NOTE: data comes from SAT_plots.R
data$instance <- sub("results/", "", data$instance)
df4 <- melt(changes, id.vars = c("instance", "dataset", "encoding"), measure.vars = c("before_variables", "after_variables"))
df4$encoding[df4$variable == "after_variables"] <- paste(df4$encoding[df4$variable == "after_variables"], "pp", sep = "")
df <- data[data$novelty == "new",] %>% left_join(df4, by = c("instance", "encoding"))

ggplot(df, aes(value, inference_time, col = dataset.y, shape = dataset.y)) + geom_point()

# ========== Numerical ==========

median(changes$before_variables[changes$encoding == "bklm16"])
median(changes$after_variables[changes$encoding == "bklm16"])

summary(changes$before_variables)
summary(changes$before_clauses)

summary(changes$after_variables[changes$encoding == "bklm16"] / changes$before_variables[changes$encoding == "bklm16"])
summary(1 - changes$after_variables[changes$encoding != "sbk05"] / changes$before_variables[changes$encoding != "sbk05"])
hist(changes$after_variables[changes$encoding != "sbk05"] / changes$before_variables[changes$encoding != "sbk05"])
changes$diff <- 1 - changes$after_variables / changes$before_variables
