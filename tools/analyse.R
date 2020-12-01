require(ggplot2)
require(scales)
require(dplyr)
require(maditr)
require(purrr)
require(tikzDevice)
require(ggpubr)
require(tidyr)

TIMEOUT <- 1000
data <- read.csv("../results.csv", header = TRUE, sep = ",")
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
            fun.aggregate = sum,
            value.var = c("answer", "time"))
time_columns <- Filter(function(x) startsWith(x, "time_"), names(df))
time_columns0 <- time_columns[time_columns != "time_new_cw"]
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

# instance_to_min_time <- df$time_min
# names(instance_to_min_time) <- df$instance
# instance_to_min_time0 <- df$time_min0
# names(instance_to_min_time0) <- df$instance
# df.temp <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS1", answer = NA, time = instance_to_min_time[df$instance])
# df.temp2 <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS0", answer = NA, time = instance_to_min_time0[df$instance])
# data_sum <- rbind(data_sum, df.temp, df.temp2)

# ============ Numerical investigations ================

df %>% group_by(df$dataset) %>% tally()

# Where answers don't match
interesting <- df[abs(df$answer_new_cw - df$answer_new_bklm16) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_new_d02) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_new_sbk05) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_old_bklm16) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_old_cd05) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_old_cd06) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_old_d02) > 0.01,]
interesting <- df[abs(df$answer_new_cw - df$answer_old_sbk05) > 0.01,]

# Number of instances
nrow(df)

# Unique
# bklm16
sum(!is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cd05
sum(is.na(df$answer_bklm16) & !is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cd06
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & !is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cw
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      !is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# d02
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & !is.na(df$answer_d02) & is.na(df$answer_sbk05))
# sbk05
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & !is.na(df$answer_sbk05))

# Fastest
sum(!is.na(df$answer_bklm16) & abs(df$time_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd05) & abs(df$time_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd06) & abs(df$time_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cw) & abs(df$time_cw - df$time_min) < 1e-5)
sum(!is.na(df$answer_d02) & abs(df$time_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_sbk05) & abs(df$time_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_bklm16))
sum(!is.na(df$answer_cd05))
sum(!is.na(df$answer_cd06))
sum(!is.na(df$answer_cw))
sum(!is.na(df$answer_d02))
sum(!is.na(df$answer_sbk05))

# ================ Plots ==========================

# Scatter plot
scatter_plot <- function(df, x_column, y_column, x_name, y_name, groupby,
                         groupby_name, max.time) {
  ggplot(df[df[[x_column]] > 0,], aes(x = .data[[x_column]],
                                      y = .data[[y_column]],
                                      col = .data[[groupby]],
                                      shape = .data[[groupby]])) +
    geom_point(alpha = 0.5, size = 1) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = c(min.time, max.time)) +
#                       breaks = c(0.1, 10, 1000),
#                       labels = c("0.1", "10", "1000")) +
    scale_y_continuous(trans = log10_trans(), limits = c(min.time, max.time)) +
#                       breaks = c(0.1, 10, 1000),
#                       labels = c("0.1", "10", "1000")) +
    ylab(y_name) +
    xlab(x_name) +
    scale_color_brewer(palette = "Dark2", name = groupby_name) +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light() +
    labs(color = groupby_name, shape = groupby_name)
}

# Compare CW with other encodings
p1 <- scatter_plot(df, "time_old_cd06", "time_new_cw", "\\texttt{old_cd06} time (s)",
                   "\\texttt{cw} time (s)", "major.dataset", "Data set",
                   2 * TIMEOUT)
p2 <- scatter_plot(df, "time_old_d02", "time_new_d02",
                   "\\texttt{old_d02} time (s)", "\\texttt{new_d02} time (s)",
                   "major.dataset", "Data set", 2 * TIMEOUT)

# Compare encoding and inference time for old and new setups
# TODO: export these plots separately (to add subcaptions)
p1 <- scatter_plot(data[data$novelty == "old",], "encoding_time", "inference_time",
                   "Encoding time (s)", "Inference time (s)", "encoding",
                   "Encoding", TIMEOUT)
p2 <- scatter_plot(data[data$novelty == "new",], "encoding_time", "inference_time",
                   "Encoding time (s)", "Inference time (s)", "encoding",
                   "Encoding", TIMEOUT)

tikz(file = "paper/scatter.tex", width = 6.5, height = 2.5)
ggarrange(p2, p1, ncol = 2, common.legend = TRUE, legend = "right")
dev.off()

# Cumulative plot
cumulative_plot <- function(df, column_name, pretty_column_name, column_values,
                            linetypes) {
  times <- vector(mode = "list", length = length(column_values))
  names(times) <- column_values
  for (value in column_values) {
    times[[value]] <- unique(df$time[df[[column_name]] == value])
  }
  chunks <- vector(mode = "list", length = length(column_values))
  names(chunks) <- column_values
  for (value in column_values) {
    chunks[[value]] <- cbind(times[[value]], value,
                             unlist(times[[value]] %>%
                                      map(function(x)
                                        sum(df$time[df[[column_name]] == value]
                                            <= x))))
  }
  cumulative <- as.data.frame(do.call(rbind, as.list(chunks)))
  names(cumulative) <- c("time", column_name, "count")
  cumulative[[column_name]] <- as.factor(paste("\\texttt{",
                                               cumulative[[column_name]], "}",
                                               sep = ""))
  cumulative$time <- as.numeric(cumulative$time)
  cumulative$count <- as.numeric(cumulative$count)
  cumulative <- cumulative[cumulative$time < TIMEOUT, ]
  ggplot(cumulative, aes(x = time, y = count, color = .data[[column_name]])) +
    geom_line(aes(linetype = .data[[column_name]])) +
#    geom_line() +
#    scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
    scale_x_continuous(trans = log10_trans()) +
    xlab("Time (s)") +
    ylab("Instances solved") +
#    scale_colour_brewer(palette = "Dark2") +
    scale_colour_manual(values = c(2, 3, 4, 1, 5, 6, 2, 3, 4, 5, 6)) +
    scale_linetype_manual(breaks = map(column_values, function(x)
      paste("\\texttt{", x, "}", sep = "")), values = linetypes) +
    annotation_logticks(sides = "b", colour = "#989898") +
    theme_light() +
    labs(color = pretty_column_name, linetype = pretty_column_name)
}

# TODO: 11 lines in one plot is too much. Should I split it into two?
df2 <- data_sum[data_sum$dataset == "Grid-50" & !is.na(data_sum$dataset),]
df2 <- data_sum
tikz(file = "paper/cumulative.tex", width = 3, height = 1.6)
cumulative_plot(df2, "encoding", "Encoding",
                sort(unique(df2$encoding)),
                c(1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3))
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
novelties <- c("Originally", "With ADDMC")
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

# Numerical stuff
max_d02 <- max(cumulative$count[cumulative$encoding == "\\texttt{d02}"])
interpolation <- approx(x = cumulative$count[cumulative$encoding == "\\texttt{cw}"],
                        y = cumulative$time[cumulative$encoding == "\\texttt{cw}"],
                        xout = max_d02)$y
