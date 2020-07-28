require(ggplot2)
require(scales)
require(dplyr)
require(maditr)
require(purrr)
require(tikzDevice)
require(ggpubr)

TIMEOUT <- 1000
df0 <- read.csv("results.csv", header = TRUE, sep = ",")
df0$time[df0$time > TIMEOUT] <- TIMEOUT
df0$time[is.na(df0$time)] <- TIMEOUT
df0$memory[is.na(df0$memory)] <- max(df0$memory)
df <- dcast(data = df0, formula = instance + dataset ~ encoding, fun.aggregate = sum, value.var = c("answer", "time", "memory"))
df$major.dataset <- df$dataset
df$major.dataset[df$dataset == "DQMR-50"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-60"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-70"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-100"] <- "DQMR"
df$major.dataset[df$dataset == "Grid-50"] <- "Grid"
df$major.dataset[df$dataset == "Grid-75"] <- "Grid"
df$major.dataset[df$dataset == "Grid-90"] <- "Grid"
df$time_min <- as.numeric(apply(df, 1, function (row) min(row["time_cd05"], row["time_cd06"],
                                                          row["time_d02"], row["time_db20"], row["time_sbk05"])))
# ============ Numerical investigations ================

# Where answers don't match
interesting <- df[abs(df$answer_db20 - df$answer_sbk05) > 0.01,]

nrow(df)

# Unique
sum(is.na(df$answer_db20) & !is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # cd05
sum(is.na(df$answer_db20) & is.na(df$answer_cd05) & !is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # cd06
sum(is.na(df$answer_db20) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      !is.na(df$answer_d02) & is.na(df$answer_sbk05)) # d02
sum(!is.na(df$answer_db20) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # db20
sum(is.na(df$answer_db20) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & !is.na(df$answer_sbk05)) # sbk05

# Fastest
sum(!is.na(df$answer_cd05) & abs(df$time_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd06) & abs(df$time_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_d02) & abs(df$time_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_db20) & abs(df$time_db20 - df$time_min) < 1e-5)
sum(!is.na(df$answer_sbk05) & abs(df$time_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_cd05))
sum(!is.na(df$answer_cd06))
sum(!is.na(df$answer_d02))
sum(!is.na(df$answer_db20))
sum(!is.na(df$answer_sbk05))

# ================ Plots ==========================

# Scatter plot: by dataset
# Consider:
# 1. Shapes as well as colors (set manually).
# 2. Adjust the alpha value.

min.time <- min(df0$time) + 0.001
p1 <- ggplot(df[df$time_d02 > 0,], aes(x = time_d02, y = time_db20, col = major.dataset)) +
  geom_point(alpha = 0.5, size = 1) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898") +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  ylab("\\texttt{db20} time (s)") +
  xlab("\\texttt{d02} time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed() +
  annotation_logticks(colour = "#b3b3b3") +
  theme_light()
p2 <- ggplot(df[df$time_sbk05 > 0,], aes(x = time_sbk05, y = time_db20, col = major.dataset)) +
  geom_point(alpha = 0.5, size = 1) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898") +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  ylab("\\texttt{db20} time (s)") +
  xlab("\\texttt{sbk05} time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed() +
  annotation_logticks(colour = "#b3b3b3") +
  theme_light()
tikz(file = "paper/scatter.tex", width = 4.8, height = 3)
ggarrange(p1, p2, ncol = 2, common.legend = TRUE, legend = "bottom")
dev.off()

# Scatter plot: for a specific data set
ggplot(df[df$dataset == "2004-PGM"], aes(x = time_db20, y = time_sbk05)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  xlim(0, TIMEOUT) +
  ylim(0, TIMEOUT)

# Cumulative plot
times <- unique(df0$time)
cumulative <- rbind.data.frame(cbind(times, "cd05", unlist(times %>% map(function(x) sum(df0$time[df0$encoding == "cd05"] <= x)))),
      cbind(times, "cd06", unlist(times %>% map(function(x) sum(df0$time[df0$encoding == "cd06"] <= x)))),
      cbind(times, "d02", unlist(times %>% map(function(x) sum(df0$time[df0$encoding == "d02"] <= x)))),
      cbind(times, "db20", unlist(times %>% map(function(x) sum(df0$time[df0$encoding == "db20"] <= x)))),
      cbind(times, "sbk05", unlist(times %>% map(function(x) sum(df0$time[df0$encoding == "sbk05"] <= x)))))
names(cumulative) <- c("time", "encoding", "count")
cumulative$encoding <- as.factor(paste("\\texttt{", cumulative$encoding, "}", sep = ""))
cumulative$time <- as.numeric(cumulative$time)
cumulative$count <- as.numeric(cumulative$count)
cumulative <- cumulative[cumulative$time < TIMEOUT, ]

tikz(file = "paper/cumulative.tex", width = 4.8, height = 2.4)
ggplot(cumulative, aes(x = time, y = count, color = encoding)) +
  geom_line() +
  scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  xlab("Time (s)") +
  ylab("Instances solved") +
  labs(color = "Encoding") +
  scale_colour_brewer(palette = "Dark2") +
  annotation_logticks(sides = "b", colour = "#989898") +
  theme_light()
dev.off()

# Scatter plot for memory usage (not interesting)
ggplot(df, aes(x = memory_db20, y = memory_cd06, col = major.dataset)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  scale_y_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  xlab("db20 memory usage") +
  ylab("d02 memory usage") +
  scale_color_brewer(palette = "Dark2", name = "Data set")
