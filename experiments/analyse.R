require(ggplot2)
require(scales)
require(dplyr)
require(maditr)

TIMEOUT <- 1
df <- read.csv("results.csv", header = TRUE, sep = ",")
df$time[df$time > TIMEOUT] <- TIMEOUT
df$time[is.na(df$time)] <- TIMEOUT
answers <- dcast(data = df, formula = instance ~ encoding, fun.aggregate = sum, value.var = "answer")
time <- dcast(data = df, formula = instance + dataset ~ encoding, fun.aggregate = sum, value.var = "time")

# Where answers don't match
interesting <- answers[abs(answers$db20 - answers$cd05) > 0.01,]
answers[abs(answers$db20 - answers$cd06) > 0.01,]
answers[abs(answers$db20 - answers$d02) > 0.01,]
answers[abs(answers$db20 - answers$sbk05) > 0.01,]

# Proportion of instances where my encoding is the best
time$min <- apply(time, 1, min)
sum(time$db20 == time$min)/nrow(time)

# Proportion unsolved
sum(is.na(answers$cd05))/nrow(answers)
sum(is.na(answers$cd06))/nrow(answers)
sum(is.na(answers$d02))/nrow(answers)
sum(is.na(answers$db20))/nrow(answers)
sum(is.na(answers$sbk05))/nrow(answers)

ggplot(time, aes(x = db20, y = d02, col = dataset)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0)

ggplot(df, aes(x = encoding, y = time)) +
  geom_boxplot()
