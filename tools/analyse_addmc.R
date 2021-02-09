library(ggplot2)
library(scales)
library(dplyr)
library(maditr)
library(purrr)
library(tikzDevice)
library(ggpubr)
library(tidyr)
library(RColorBrewer)

data <- read.csv("../results/old_results.csv", header = TRUE, sep = ",")
data <- data[!(data$encoding == "cd05" & data$novelty == "new"),]
data <- data[!(data$encoding == "cd06" & data$novelty == "new"),]

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
            fun.aggregate = min,
            value.var = c("answer", "time"))
time_columns <- Filter(function(x) startsWith(x, "time_"), names(df))
df$time_min <- as.numeric(apply(df, 1, function (row) min(row[time_columns])))
for (column in time_columns) {
  df[is.na(df[[column]]), column] <- 2 * TIMEOUT
}

df$major.dataset <- "Non-binary"
df$major.dataset[grepl("DQMR", df$instance, fixed = TRUE)] <- "DQMR"
df$major.dataset[grepl("Grid", df$instance, fixed = TRUE)] <- "Grid"
df$major.dataset[grepl("mastermind", df$instance, fixed = TRUE)] <- "Mastermind"
df$major.dataset[grepl("blockmap", df$instance, fixed = TRUE)] <- "Random Blocks"
df$major.dataset[grepl("fs-", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("Plan_Recognition", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("students", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("tcc4f", df$instance, fixed = TRUE)] <- "Other binary"

data_sum$encoding[data_sum$encoding == "new_bklm16"] <- "\\textsf{ADDMC} + \\texttt{bklm16}"
data_sum$encoding[data_sum$encoding == "new_cw"] <- "\\textsf{ADDMC} + \\texttt{cw}"
data_sum$encoding[data_sum$encoding == "new_d02"] <- "\\textsf{ADDMC} + \\texttt{d02}"
data_sum$encoding[data_sum$encoding == "new_sbk05"] <- "\\textsf{ADDMC} + \\texttt{sbk05}"
data_sum$encoding[data_sum$encoding == "old_bklm16"] <- "\\textsf{query-dnnf} + \\texttt{bklm16}"
data_sum$encoding[data_sum$encoding == "old_cd05"] <- "\\textsf{Ace} + \\texttt{cd05}"
data_sum$encoding[data_sum$encoding == "old_cd06"] <- "\\textsf{Ace} + \\texttt{cd06}"
data_sum$encoding[data_sum$encoding == "old_d02"] <- "\\textsf{Ace} + \\texttt{d02}"
data_sum$encoding[data_sum$encoding == "old_sbk05"] <- "\\textsf{Cachet} + \\texttt{sbk05}"

# ==================== Plots ====================

# brewer.pal(12, "Paired")
colours <- c("#FDBF6F", "#FB9A99", "#B2DF8A", "#1F78B4", "#B15928", "#33A02C", "#6A3D9A", "#CAB2D6", "#A6CEE3")
cumulative_plot <- function(df, column_name, pretty_column_name, column_values,
                            linetypes, variable, variable_name) {
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
  cumulative[[column_name]] <- as.factor(cumulative[[column_name]])
  cumulative$time <- as.numeric(cumulative$time)
  cumulative$count <- as.numeric(cumulative$count)
  cumulative <- cumulative[cumulative$time < 2 * TIMEOUT, ]
  ggplot(cumulative, aes(x = time, y = count, color = .data[[column_name]])) +
    geom_line(aes(linetype = .data[[column_name]])) +
    scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 1, 10, 100, 1000), labels = c("0.1", "1", "10", "100", "1000")) +
    xlab("Time (s)") +
    ylab("Instances solved") +
    scale_colour_manual(breaks = column_values, values = colours) +
    scale_linetype_manual(breaks = column_values, values = linetypes) +
    annotation_logticks(sides = "b", colour = "#989898") +
    theme_light() +
    labs(color = pretty_column_name, linetype = pretty_column_name)
}

tikz(file = "../doc/paper2/cumulative.tex", width = 6.5, height = 2.4)
cumulative_plot(data_sum, "encoding", "Algorithm \\& Encoding",
                sort(unique(data_sum$encoding)),
                c(2, 2, 2, 1, 1, 1, 1, 2, 2), "time", "Time (s)")
dev.off()

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
    labs(shape = "Data set", colour = "Data set") +
    scale_color_brewer(palette = "Dark2") +
    scale_shape("Data set")
}

p1 <- scatter_plot(df, "time_old_cd06", "time_new_cw", "\\textsf{Ace} + \\texttt{cd06} time (s)",
                   "\\textsf{ADDMC} + \\texttt{cw} time (s)", 2 * TIMEOUT)

p2 <- scatter_plot(df, "time_new_sbk05", "time_new_cw", "\\textsf{ADDMC} + \\texttt{sbk05} time (s)",
                   "\\textsf{ADDMC} + \\texttt{cw} time (s)", 2 * TIMEOUT)
tikz(file = "../doc/paper2/scatter.tex", width = 6.5, height = 2.4)
ggarrange(p1, p2, ncol = 2, nrow = 1, common.legend = TRUE, legend = "right")
dev.off()

data_melted <- melt(data[!is.na(data$answer),], id = c("encoding", "novelty"),
                    measure = c("encoding_time", "inference_time")) %>%
  group_by(encoding, novelty, variable) %>%
  summarize(time = mean(value), lower = mean(value) - 0.1 * sd(value),
            upper = mean(value) + 0.1 * sd(value))
data_melted$encoding <- paste0("\\texttt{", data_melted$encoding, "}", sep = "")
data_melted$lower[data_melted$variable =="inference_time"] <- with(data_melted, lower[variable == "encoding_time"] + lower[variable == "inference_time"])
data_melted$upper[data_melted$variable =="inference_time"] <- with(data_melted, upper[variable == "encoding_time"] + upper[variable == "inference_time"])
data_melted$novelty <- factor(data_melted$novelty, levels = c("old", "new"))
novelties <- c("Originally", "With \\textsf{ADDMC}")
names(novelties) <- c("old", "new")

tikz(file = "../doc/paper2/melt.tex", width = 6.5, height = 2.4)
ggplot(data_melted, aes(encoding, time, fill = variable)) +
  geom_bar(stat="identity", position = position_stack(reverse = TRUE)) +
  facet_grid(cols = vars(novelty), labeller = labeller(novelty = novelties)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.3, position = "identity") +
  theme_light() +
  scale_fill_brewer(palette = "Dark2", labels = c("Encoding", "Inference")) +
  xlab("") +
  ylab("Time (s)") +
  labs(fill = "")
dev.off()

# ==================== Numerics ====================

# Unique
answer_columns <- Filter(function(x) startsWith(x, "answer_"), names(df))
for (column in answer_columns) {
  other_columns <- answer_columns[answer_columns != column]
  print(column)
  print(sum(apply(!is.na(df[[column]]) & is.na(df[,..other_columns]), 1, min)))
}

# Fastest
sum(!is.na(df$answer_new_cw) & abs(df$time_new_cw - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_bklm16) & abs(df$time_new_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_d02) & abs(df$time_new_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_sbk05) & abs(df$time_new_sbk05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_bklm16) & abs(df$time_old_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd05) & abs(df$time_old_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd06) & abs(df$time_old_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_d02) & abs(df$time_old_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_sbk05) & abs(df$time_old_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_new_cw))
sum(!is.na(df$answer_new_bklm16))
sum(!is.na(df$answer_new_d02))
sum(!is.na(df$answer_new_sbk05))
sum(!is.na(df$answer_old_bklm16))
sum(!is.na(df$answer_old_cd05))
sum(!is.na(df$answer_old_cd06))
sum(!is.na(df$answer_old_d02))
sum(!is.na(df$answer_old_sbk05))
