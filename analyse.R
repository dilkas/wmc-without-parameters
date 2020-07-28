require(ggplot2)
require(scales)
require(dplyr)
require(maditr)
require(purrr)

TIMEOUT <- 1000
df0 <- read.csv("results.csv", header = TRUE, sep = ",")
df0$time[df0$time > TIMEOUT] <- TIMEOUT
df0$time[is.na(df0$time)] <- TIMEOUT
df <- dcast(data = df0, formula = instance + dataset ~ encoding, fun.aggregate = sum, value.var = c("answer", "time", "memory"))
df$major.dataset <- df$dataset
df$major.dataset[df$dataset == "DQMR-50"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-60"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-70"] <- "DQMR"
df$major.dataset[df$dataset == "DQMR-100"] <- "DQMR"
df$major.dataset[df$dataset == "Grid-50"] <- "Grid"
df$major.dataset[df$dataset == "Grid-75"] <- "Grid"
df$major.dataset[df$dataset == "Grid-90"] <- "Grid"

# Where answers don't match
interesting <- df[abs(df$answer_db20 - df$answer_sbk05) > 0.01,]

# Proportion of instances where my encoding is the best
#time$min <- apply(time, 1, min)
#sum(time$db20 == time$min)/nrow(time)

# Proportion unsolved
sum(is.na(df$answer_cd05))/nrow(df)
sum(is.na(df$answer_cd06))/nrow(df)
sum(is.na(df$answer_d02))/nrow(df)
sum(is.na(df$answer_db20))/nrow(df)
sum(is.na(df$answer_sbk05))/nrow(df)

# Scatter plot: by dataset
# Consider:
# 1. Shapes as well as colors (set manually).
# 2. Adjust the alpha value.

# D02
min.time <- min(df0$time) + 0.001
ggplot(df[df$time_d02 > 0,], aes(x = time_db20, y = time_d02, col = major.dataset)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT)) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT)) +
  xlab("db20 time (s)") +
  ylab("d02 time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed()

ggplot(df, aes(x = time_db20, y = time_sbk05, col = major.dataset)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT)) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT)) +
  xlab("db20 time (s)") +
  ylab("sbk05 time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed()

# Scatter plot: for a specific dataset
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
cumulative$encoding <- as.factor(cumulative$encoding)
cumulative$time <- as.numeric(cumulative$time)
cumulative$count <- as.numeric(cumulative$count)
cumulative <- cumulative[cumulative$time < TIMEOUT, ]

ggplot(cumulative, aes(x = time, y = count, color = encoding)) +
  geom_line() +
  scale_x_continuous(trans = log10_trans()) +
  xlab("Time (s)") +
  ylab("Instances solved") +
  labs(color = "Encoding") +
  scale_colour_brewer(palette = "Dark2")

# Scatter plot for memory usage (not interesting)
ggplot(df, aes(x = memory_db20, y = memory_cd06, col = major.dataset)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  scale_y_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  xlab("db20 memory usage") +
  ylab("d02 memory usage") +
  scale_color_brewer(palette = "Dark2", name = "Data set")
