library(ggplot2)
library(scales)
library(dplyr)
library(maditr)
library(purrr)
library(tikzDevice)
library(ggpubr)
library(tidyr)
library(RColorBrewer)

# ==================== PREPROCESSING ====================
data <- read.csv("../results/results.csv", header = TRUE, sep = ",")

TIMEOUT <- 1000
data$inference_time[is.na(data$inference_time)] <- TIMEOUT
min.time <- min(min(data$encoding_time[data$encoding_time > 0]),
                min(data$inference_time[data$inference_time > 0]))
data$encoding_time[data$encoding_time == 0] <- min.time
data$inference_time[data$inference_time == 0] <- min.time
data$answer[data$encoding_time >= TIMEOUT] <- NA
data$answer[data$inference_time >= TIMEOUT] <- NA
data$encoding_time[is.na(data$answer)] <- TIMEOUT
data$inference_time[is.na(data$answer)] <- TIMEOUT

# Merge 'novelty' and 'encoding' columns
data_merged <- data
data_merged$encoding <- paste(data_merged$novelty, data_merged$encoding, sep = "_")
data_merged <- subset(data_merged, select = -c(novelty))

# Add encoding and inference times
data_sum <- data_merged
data_sum$time <- data_sum$encoding_time + data_sum$inference_time
data_sum <- subset(data_sum, select = -c(inference_time, encoding_time))

df <- dcast(data = data_sum, formula = instance + dataset ~ encoding,
            fun.aggregate = NULL,
            value.var = c("answer", "time", "add_width", "treewidth"))
time_columns <- Filter(function(x) startsWith(x, "time_"), names(df))
time_columns0 <- time_columns[!grepl('pp$', time_columns)]
for (column in time_columns) {
  df[is.na(df[[column]]), column] <- 2 * TIMEOUT
}

# df$treewidth <- apply(df %>% select(starts_with("treewidth")), 1,
#                       function(x) max(x, na.rm = TRUE))
# df <- df %>% select(!starts_with("treewidth_"))
# df$treewidth <- df$treewidth - 1

df$time_min <- as.numeric(apply(df, 1, function (row) min(row[time_columns])))
df$time_min0 <- as.numeric(apply(df, 1, function (row) min(row[time_columns0])))
df$major.dataset <- "Non-binary"
df$major.dataset[grepl("DQMR", df$instance, fixed = TRUE)] <- "DQMR"
df$major.dataset[grepl("Grid", df$instance, fixed = TRUE)] <- "Grid"
df$major.dataset[grepl("mastermind", df$instance, fixed = TRUE)] <- "Mastermind"
df$major.dataset[grepl("blockmap", df$instance, fixed = TRUE)] <- "Random Blocks"
df$major.dataset[grepl("fs-", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("Plan_Recognition", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("students", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("tcc4f", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset <- as.factor(df$major.dataset)

instance_to_min_time <- df$time_min
names(instance_to_min_time) <- df$instance
instance_to_min_time0 <- df$time_min0
names(instance_to_min_time0) <- df$instance
rownames(data_sum) <- c()

data_sum$encoding[data_sum$encoding == "new_bklm16"] <- "\\textsf{DPMC} + \\texttt{bklm16}"
data_sum$encoding[data_sum$encoding == "new_bklm16pp"] <- "\\textsf{DPMC} + \\texttt{bklm16++}"
data_sum$encoding[data_sum$encoding == "new_cd05pp"] <- "\\textsf{DPMC} + \\texttt{cd05++}"
data_sum$encoding[data_sum$encoding == "new_cd06pp"] <- "\\textsf{DPMC} + \\texttt{cd06++}"
data_sum$encoding[data_sum$encoding == "new_d02"] <- "\\textsf{DPMC} + \\texttt{d02}"
data_sum$encoding[data_sum$encoding == "new_d02pp"] <- "\\textsf{DPMC} + \\texttt{d02++}"
data_sum$encoding[data_sum$encoding == "new_sbk05"] <- "\\textsf{DPMC} + \\texttt{sbk05}"
data_sum$encoding[data_sum$encoding == "old_bklm16"] <- "\\textsf{c2d} + \\texttt{bklm16}"
data_sum$encoding[data_sum$encoding == "old_cd05"] <- "\\textsf{Ace} + \\texttt{cd05}"
data_sum$encoding[data_sum$encoding == "old_cd06"] <- "\\textsf{Ace} + \\texttt{cd06}"
data_sum$encoding[data_sum$encoding == "old_d02"] <- "\\textsf{Ace} + \\texttt{d02}"
data_sum$encoding[data_sum$encoding == "old_sbk05"] <- "\\textsf{Cachet} + \\texttt{sbk05}"

# ============ Numerical investigations ================

df$diff <-df$time_new_bklm16pp - df$time_new_bklm16
summary(df$diff)

# Total time per data set (for job scheduling)
sum(data$encoding_time[startsWith(data$dataset, "Grid")]) + sum(data$inference_time[startsWith(data$dataset, "Grid")])
sum(data$encoding_time[startsWith(data$dataset, "DQMR")]) + sum(data$inference_time[startsWith(data$dataset, "DQMR")])
sum(data$encoding_time[startsWith(data$dataset, "Plan")]) + sum(data$inference_time[startsWith(data$dataset, "Plan")])
sum(data$encoding_time[startsWith(data$dataset, "2004")]) + sum(data$inference_time[startsWith(data$dataset, "2004")])
sum(data$encoding_time[startsWith(data$dataset, "2005")]) + sum(data$inference_time[startsWith(data$dataset, "2005")])
sum(data$encoding_time[startsWith(data$dataset, "2006")]) + sum(data$inference_time[startsWith(data$dataset, "2006")])

# The numbers of instances per data set (so I can check if each instance is included)
tallies <- df %>% group_by(df$dataset) %>% tally()
sum(tallies$n)
df %>% group_by(df$major.dataset) %>% tally()

# Where answers don't match
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_bklm16) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_bklm16pp) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_d02) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_sbk05) > 0.01,]

interesting <- df[abs(df$answer_old_cd06 - df$answer_old_bklm16) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_cd05) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_d02) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_sbk05) > 0.01,]

# Number of instances
nrow(df)

# Unique
answer_columns <- Filter(function(x) startsWith(x, "answer_"), names(df))
for (column in answer_columns) {
  other_columns <- answer_columns[answer_columns != column]
  print(column)
  print(sum(apply(!is.na(df[[column]]) & is.na(df[,..other_columns]), 1, min)))
}

# Fastest
sum(!is.na(df$answer_new_bklm16) & abs(df$time_new_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_bklm16pp) & abs(df$time_new_bklm16pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_cd05pp) & abs(df$time_new_cd05pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_cd06pp) & abs(df$time_new_cd06pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_d02) & abs(df$time_new_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_d02pp) & abs(df$time_new_d02pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_sbk05) & abs(df$time_new_sbk05 - df$time_min) < 1e-5)

sum(!is.na(df$answer_old_bklm16) & abs(df$time_old_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd05) & abs(df$time_old_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd06) & abs(df$time_old_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_d02) & abs(df$time_old_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_sbk05) & abs(df$time_old_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_new_bklm16))
sum(!is.na(df$answer_new_bklm16pp))
sum(!is.na(df$answer_new_cd05pp))
sum(!is.na(df$answer_new_cd06pp))
sum(!is.na(df$answer_new_d02))
sum(!is.na(df$answer_new_d02pp))
sum(!is.na(df$answer_new_sbk05))

sum(!is.na(df$answer_old_bklm16))
sum(!is.na(df$answer_old_cd05))
sum(!is.na(df$answer_old_cd06))
sum(!is.na(df$answer_old_d02))
sum(!is.na(df$answer_old_sbk05))

# ================ Plots ==========================

# Scatter plot
scatter_plot <- function(df, x_column, y_column, x_name, y_name,
                         max.time) {
  ggplot(df[df[[x_column]] > 0,], aes(x = .data[[x_column]],
                                      y = .data[[y_column]],
                                      col = major.dataset,
                                      shape = major.dataset)) +
    geom_point(alpha = 0.5, size = 1) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = c(min.time, max.time),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    scale_y_continuous(trans = log10_trans(), limits = c(min.time, max.time),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    ylab(y_name) +
    xlab(x_name) +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light() +
    labs(shape = "", colour = "") +
    scale_color_brewer(palette = "Dark2")
}

# For the paper
p1 <- scatter_plot(df, "time_old_cd06", "time_new_bklm16pp", "\\textsf{Ace} + \\texttt{cd06} time (s)",
                   "\\textsf{DPMC} + \\texttt{bklm16++} time (s)", 2 * TIMEOUT)
p2 <- scatter_plot(df, "time_new_bklm16", "time_new_bklm16pp", "\\textsf{DPMC} + \\texttt{bklm16} time (s)",
                   "\\textsf{DPMC} + \\texttt{bklm16++} time (s)", 2 * TIMEOUT)
tikz(file = "../doc/SAT_paper/scatter.tex", width = 4.8, height = 2.9, standAlone = TRUE)
ggarrange(p1, p2, ncol = 2, nrow = 1, common.legend = TRUE, legend = "bottom")
dev.off()

# For slides
tikz(file = "../doc/SAT_long_talk/scatter1.tex", width = 4.2, height = 3.1, standAlone = TRUE)
scatter_plot(df, "time_old_cd06", "time_new_bklm16pp", "\\textsf{Ace} + \\texttt{cd06} time (s)", "\\textsf{DPMC} + \\texttt{bklm16++} time (s)", 2 * TIMEOUT)
dev.off()
tikz(file = "../doc/SAT_long_talk/scatter2.tex", width = 4.2, height = 3.1, standAlone = TRUE)
scatter_plot(df, "time_new_bklm16", "time_new_bklm16pp", "\\textsf{DPMC} + \\texttt{bklm16} time (s)", "\\textsf{DPMC} + \\texttt{bklm16++} time (s)", 2 * TIMEOUT)
dev.off()

scatter_plot(df, "time_new_d02pp", "time_new_d02", "\\texttt{d02++} time (s)",
                   "\\texttt{d02} time (s)", max(data$add_width))
scatter_plot(df, "add_width_new_bklm16pp", "add_width_new_sbk05", "\\texttt{bklm16++} width",
                   "\\texttt{sbk05} width", max(data$add_width))
scatter_plot(df, "treewidth", "add_width_new_bklm16", "treewidth",
                   "\\texttt{bklm16} width", max(data$add_width))
scatter_plot(data, "add_width", "inference_time", "ADD width", "time", 2 * TIMEOUT)

cumulative_plot <- function(df, column_name, pretty_column_name, variable,
                            variable_name, show.color.legend,
                            show.linetype.legend, position, column_values,
                            to_highlight, colours) {
  times <- vector(mode = "list", length = length(column_values))
  names(times) <- column_values
  for (value in column_values) {
    times[[value]] <- unique(df[df[[column_name]] == value, variable])
  }
  chunks <- vector(mode = "list", length = length(column_values))
  names(chunks) <- column_values
  for (value in column_values) {
    chunks[[value]] <- cbind(times[[value]], value,
                             unlist(times[[value]] %>%
                                      map(function(x)
                                        sum(df[df[[column_name]] == value, variable]
                                            <= x))))
  }
  cumulative <- as.data.frame(do.call(rbind, as.list(chunks)))
  names(cumulative) <- c("time", column_name, "count")
  cumulative$algorithm <- ifelse(grepl("DPMC", cumulative$encoding, fixed = TRUE), "\\textsf{DPMC}", "other")
  cumulative$encoding <- sub(".*\\+ ", "", cumulative$encoding)
  cumulative[[column_name]] <- as.factor(cumulative[[column_name]])
  cumulative$algorithm <- as.factor(cumulative$algorithm)
  cumulative$time <- as.numeric(cumulative$time)
  cumulative$count <- as.numeric(cumulative$count)
  cumulative <- cumulative[cumulative$time < 2 * TIMEOUT, ]
  alpha_scale <- ifelse(colours == "#989898", 0.15, 1)
  p <- ggplot(cumulative, aes(x = count, y = time,
                              color = .data[[column_name]],
                              alpha = .data[[column_name]])) +
    geom_line(aes(linetype = algorithm)) +
    scale_y_continuous(trans = log10_trans(), breaks = c(0.1, 1, 10, 100, 1000),
                       labels = c("0.1", "1", "10", "100", "1000")) +
    ylab("Time (s)") +
    xlab("Instances solved") +
    annotation_logticks(sides = "l", colour = "#989898") +
    labs(color = pretty_column_name, linetype = "Algorithm",
         alpha = pretty_column_name) +
    geom_vline(xintercept = 1466, linetype = "dotted", color = "black") +
    scale_alpha_manual(values = alpha_scale)

  if (show.color.legend) {
    p <- p + scale_colour_manual(breaks = sort(unique(cumulative$encoding)),
                        values = colours) +
      guides(color = guide_legend(ncol = 2)) +
      theme(legend.position = position, panel.grid.major = element_blank(),
            panel.grid.minor = element_blank())
  } else {
    p <- p + scale_colour_manual(breaks = sort(unique(cumulative$encoding)),
                        values = colours, guide = show.color.legend) +
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
  }
  if (show.linetype.legend) {
    p <- p + scale_linetype_manual(breaks = sort(unique(cumulative$algorithm)),
                          values = c(1, 2)) +
      theme(legend.position = position, panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
      guides(linetype = guide_legend(ncol = 2))
  } else {
     p <- p + scale_linetype_manual(breaks = sort(unique(cumulative$algorithm)),
                          values = c(1, 2), guide = show.linetype.legend) +
       theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
  }
  # Calculate how many times my best encoding is faster than others
  #max <- max(cumulative$count[cumulative$algorithm == "other" &
  #                                cumulative$encoding == "\\texttt{cd06}"])
  #interpolation <- approx(x = cumulative$count[cumulative$encoding == "\\texttt{bklm16++}"],
  #                        y = cumulative$time[cumulative$encoding == "\\texttt{bklm16++}"],
  #                        xout = max)$y
  #print(interpolation)
  #max <- max(cumulative$count[cumulative$algorithm == "\\textsf{DPMC}" &
  #                                cumulative$encoding == "\\texttt{bklm16}"])
  #interpolation <- approx(x = cumulative$count[cumulative$encoding == "\\texttt{bklm16++}"],
  #                        y = cumulative$time[cumulative$encoding == "\\texttt{bklm16++}"],
  #                        xout = max)$y
  #print(interpolation)
  return(p + theme_classic())
}
#brewer.pal(12, "Paired")
#tikz(file = "../doc/SAT_paper/cumulative.tex", width = 4.8, height = 2.3, standAlone = TRUE)

colours <- c("#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C", "#FB9A99",
             "#E31A1C", "#FDBF6F", "#FF7F00", "#CAB2D6", "#6A3D9A", "#FFFF99")
colours1 <- c("#989898", "#989898", "#989898", "#989898", "#989898",
              "#989898", "#FDBF6F", "#FF7F00", "#989898", "#989898", "#989898")
colours2 <- c("#989898", "#989898", "#989898", "#989898", "#989898",
              "#989898", "#989898", "#989898", "#CAB2D6", "#989898", "#989898")
colours3 <- c("#989898", "#989898", "#B2DF8A", "#33A02C", "#989898",
              "#989898", "#989898", "#989898", "#989898", "#989898", "#989898")
colours4 <- c("#989898", "#989898", "#989898", "#989898", "#FB9A99",
              "#E31A1C", "#989898", "#989898", "#989898", "#989898", "#989898")
colours5 <- c("#A6CEE3", "#1F78B4", "#989898", "#989898", "#989898",
              "#989898", "#989898", "#989898", "#989898", "#989898", "#989898")
pairs <- sort(unique(data_sum$encoding))

tikz(file = "../doc/SAT_long_talk/cumulative1.tex", width = 4.2, height = 3.1,
     standAlone = TRUE)
cumulative_plot(data_sum, "encoding", "Encoding", "time", "Time (s)", TRUE,
                TRUE, "right", pairs, "d02", colours1)
dev.off()

tikz(file = "../doc/SAT_long_talk/cumulative2.tex", width = 4.2, height = 3.1,
     standAlone = TRUE)
cumulative_plot(data_sum, "encoding", "Encoding", "time", "Time (s)", TRUE,
                TRUE, "right", pairs, "sbk05", colours2)
dev.off()

tikz(file = "../doc/SAT_long_talk/cumulative3.tex", width = 4.2, height = 3.1,
     standAlone = TRUE)
cumulative_plot(data_sum, "encoding", "Encoding", "time", "Time (s)", TRUE,
                TRUE, "right", pairs, "cd05", colours3)
dev.off()

tikz(file = "../doc/SAT_long_talk/cumulative4.tex", width = 4.2, height = 3.1,
     standAlone = TRUE)
cumulative_plot(data_sum, "encoding", "Encoding", "time", "Time (s)", TRUE,
                TRUE, "right", pairs, "cd06", colours4)
dev.off()

tikz(file = "../doc/SAT_long_talk/cumulative5.tex", width = 4.2, height = 3.1,
     standAlone = TRUE)
cumulative_plot(data_sum, "encoding", "Encoding", "time", "Time (s)", TRUE,
                TRUE, "right", pairs, "bklm16", colours5)
dev.off()

# Stacked bar plots comparing encoding and inference time
data_melted <- melt(data[!is.na(data$answer),], id = c("encoding", "novelty"),
                    measure = c("encoding_time", "inference_time")) %>%
  group_by(encoding, novelty, variable) %>%
  summarize(time = mean(value), lower = mean(value) - 0.1 * sd(value),
            upper = mean(value) + 0.1 * sd(value))
data_melted$lower[data_melted$variable =="inference_time"] <- with(data_melted, lower[variable == "encoding_time"] + lower[variable == "inference_time"])
data_melted$upper[data_melted$variable =="inference_time"] <- with(data_melted, upper[variable == "encoding_time"] + upper[variable == "inference_time"])
data_melted$novelty <- factor(data_melted$novelty, levels = c("old", "new"))
novelties <- c("Originally", "With DPMC")
names(novelties) <- c("old", "new")

ggplot(data_melted, aes(encoding, time, fill = variable)) +
  geom_bar(stat="identity", position = position_stack(reverse = TRUE)) +
  facet_grid(cols = vars(novelty), labeller = labeller(novelty = novelties)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.3, position = "identity") +
  theme_light() +
  scale_fill_brewer(palette = "Dark2", labels = c("Encoding", "Inference")) +
  xlab("") +
  ylab("Time (s)") +
  labs(fill = "")

# Plots that show how the combination of bklm16 and cd06 would do (not including tree decomposition time)
fusion <- data.frame(treewidth = unique(data$treewidth))
fusion$tops <- apply(fusion, 1, function(x) nrow(df[ifelse(df$treewidth <= x, abs(df$time_new_bklm16 - df$time_min) < 0.01, abs(df$time_old_cd06 - df$time_min) < 0.01),]))
fusion$time <- apply(fusion, 1, function(x) sum(df$time_new_bklm16[df$treewidth <= x[1]]) + sum(df$time_old_cd06[df$treewidth > x[1]]))

ggplot(data = fusion, aes(x = treewidth, y = tops)) + geom_line() + scale_x_continuous(trans = log10_trans())
ggplot(data = fusion, aes(x = treewidth, y = time)) + geom_line() + scale_x_continuous(trans = log10_trans())
sum(!is.na(df$time_min))
sum(!is.na(df$answer_new_cw) & abs(df$time_new_cw - df$time_min) < 0.01)
sum(!is.na(df$answer_old_cd06) & abs(df$time_old_cd06 - df$time_min) < 0.01)

df$diff <- df$time_new_bklm16 - df$time_old_cd06
ggplot(df, aes(treewidth, time_new_bklm16, shape = major.dataset, colour = major.dataset)) +
  geom_point() +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans())

# ADD width vs treewidth
ggplot(data, aes(treewidth, add_width, colour = encoding)) +
  geom_point(alpha = 0.5) +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans())

ggplot(df, aes(add_width_new_bklm16, add_width_new_d02, color = major.dataset)) +
  geom_point() +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans()) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898")

df$diff <- df$add_width_new_d02 - df$add_width_new_d02pp
ggplot(df, aes(diff)) + geom_density()
ggplot(df, aes(diff)) + geom_boxplot()

# Difference in treewidth
df$diff <- df$add_width_new_bklm16 - df$add_width_new_bklm16pp
df$diff <- df$add_width_new_d02 - df$add_width_new_d02pp
ggplot(df, aes(x = diff)) +
  geom_density()
