#' ---
#' title: "Demonstration of Generic Target Shuffling"
#' author: "David Marx"
#' date: "September 15, 2014"
#' ---

# /* 
#    #################################################################################
#    # NB: This R script can be compiled into a static notebook by using             #
#    # RStudio's "Compile Notebook" command or by calling knitr::spin on the script. #
#    #################################################################################  
# */


#' Target shuffling is an extremely simple algorithm for estimating the significance of a model. 
#' The idea is to use resampling to estimate the distribution of a given test statistic under the 
#' null hypothesis, and then compare our observed test statistic to the eCDF of the null derived
#' from our resampling.
#' 
#' This is really all there is to it:

# Generic Target shuffling function
tShuffle = function(k, x, y, fitModel, stat, returnValues=TRUE, estimateSignificance=TRUE, ...){
  results = rep(NULL, k)
  for(i in 1:k){
    shuffled_y = sample(y, length(y), ...)  
    results[i] = stat(fitModel(x,shuffled_y))
  }  
  retval=list()
  if(returnValues) retval$values = results
  if(estimateSignificance) retval$est_pval = 1- sum(stat(fitModel(x,y)) > results)/k
  retval
}

#' To make this function generic, I've parameterized it such that it can take any function to fit
#' a supervised model on a training dataset `x` and a target dataset `y` such that the call 
#' `fitModel(x,y)` returns an object that can be operated on by the `stat` function to return a scalar
#' value.
#' 
#' In addition to estimating significance, this implementation returns the raw results of our target shuffling
#' experiments so we can examine the estimated null distribution.
#'
#' To demonstrate, let's run a linear regression and target shuffle the R^2 to determine model significance.
#' In retrospect, really I should be target shuffling the F-statistic of the model, since that's what is
#' actually used to determine model significance, but for the purpose of generality I use r-squared here (which
#' can be calculated for any model) and you will see that we are able to make good estimates on the p-value
#' by target shuffling on this statistic instead of the F-statistic.
#' 
#' To do this, we need to define a `fitModel` function and `stat` function. The first is just a wrapper on
#' the `lm` function, the second just extracts the r.squared attribute from calling `summary` on the model
#' object returned by `lm`. These functions will be passed to the tshuffle function. Last, I'll define a
#' function to simplify extracting the observed p-value from my model.
fitModel = function(x,y){
  lm(y~x)
}

stat = function(mod){
  summary(mod)$r.squared
}

extract_pval = function(mod){
  unlist(anova(mod)[5])[1]
}

#' Let's fit our models to the famous iris data set. We'll start by fitting a "good" model (i.e. one in which
#' we expect to observe significance).
names(iris)
#mod_a = lm(Petal.Length~Petal.Width, iris)
mod_a =fitModel(iris$Petal.Width, iris$Petal.Length)
summary(mod_a)

plot(Petal.Length~Petal.Width, iris)
abline(mod_a, col='blue',lty=2)

stat(mod_a) # r-squared

#' Target shuffle our model
n=1e3
results_a = tShuffle(n, iris$Petal.Width, iris$Petal.Length, fitModel, stat, replace=TRUE)

#' Visualize results of target shuffling
plot(density(results_a$values), xlim=c(0,1), main='KDE of Target Shuffling Results')
abline(v=stat(mod_a), lty=2, col='red')
legend('top', c('Target Shuffled R2', 'Observed R2'), lty=1:2, col=1:2)

#' Compare estimated p-value with observed
print(paste("Estimated p-value:", results_a$est_pval))
print(paste("Observed p-value:",extract_pval(mod_a)))
summary(results_a$values)


#################

#' Let's contrast these results with an attempt to fit a bad model.
mod_b = lm(Sepal.Length~Sepal.Width, iris)
summary(mod_b)

plot(Sepal.Length~Sepal.Width, iris)
abline(mod_b, col='blue', lty=2)

stat(mod_b)

#' Target shuffle our model
results_b = tShuffle(n, iris$Sepal.Width, iris$Sepal.Length, fitModel, stat, replace=TRUE)

#' Visualize results of target shuffling
plot(density(results_b$values), xlim=c(0,1), main='KDE of Target Shuffling Results')
abline(v=stat(mod_b), lty=2, col='red')
legend('top', c('Target Shuffled R2', 'Observed R2'), lty=1:2, col=1:2)

print(paste("Estimated p-value:", results_b$est_pval))
print(paste("Observed p-value:",extract_pval(mod_b)))
summary(results_b$values)

#' Let's run a little experiment to observe how quickly the target shuffled significance
#' on the r^2 statistics converges to the analytic p-value for the model, and see if incorporating
#' bootstrap resampling in our target shuffle makes any difference.

run_experiment = function(x, y, k, fitModel, stat, ...){
  mod = lm(y~x)
  results = tShuffle(k, x, y, fitModel, stat, ...)
  
  p_sim = results$est_pval #sum(stat(mod) < results)/length(results)
  num = cumsum(stat(mod) < results$values)
  denom = 1: length(results$values)
  plot(denom, 
       num/denom, 
       type='l', 
       main="Running simulated p-value",
       xlab="Iteration",
       ylab="Simulated p-value"
  )
  abline(h=p_sim, col='red', lty=2)
  p_anlyt = extract_pval(mod) #unlist(anova(mod)[c("Pr(>F)")])[1]
  abline(h=p_anlyt, col='blue', lty=2)
  legend('topright', c('Running estimated p-value','Final estimated p-value', 'Observed analytic p-value'),
         lty=c(1,2,2), col=c(1:2,'blue')
  )
  
  abs_error=abs(num/denom - p_anlyt)  
  
  plot(denom, abs_error, 
       type='l', 
       main="Convergence to analytic p-value",
       xlab="Iteration",
       ylab="Absolute Error (|p_sim - p_anlyt|)",
       ylim=c(0,.05)
  )  
  return(list(results=results, p_sim=p_sim, p_analytic=p_anlyt, abs_error=abs_error))
}

#' Generic Target Shuffling
exp_f = run_experiment(iris$Sepal.Width, iris$Sepal.Length, n, fitModel, stat, replace=FALSE)
exp_f$p_sim; exp_f$p_analytic

#' Bootstrapped Target Shuffling
exp_t = run_experiment(iris$Sepal.Width, iris$Sepal.Length, n, fitModel, stat, replace=TRUE)
exp_t$p_sim; exp_t$p_analytic

#' It appears that incorporating bootstrapping with target shuffling probablydoesn't really make much 
#' of a difference.
#'
#' **Class Imbalance**
#'
#' Target shuffling is especially useful in situations where the analytic p-value may not be representative 
#' of the true null distribution. A textbook exaple is in the case of significant class imbalance: a naive
#' model will be able to achieve significant accuracy by effectively predicting that any input will be of the 
#' majority class. 

#' To demonstrate, let's construct a dataset with two randomly distributed classes (i.e. inseparable given
#' the available features) where one class is a significant minority relative to the other.

n=1e3
p=0.05
x = runif(n)
y = rbinom(n,1,p)

table(y)/n

#' Since we know that there is no conditional relationship between `x` and `y`, we know that, theoretically,
#' trying to train a logistic regression on this data would be fruitless. But the class imbalance will give
#' us deceptive results.


fitModel_log = function(x,y){
  glm(y~x, data.frame(x,y),family='binomial')
}

accuracy = function(mod, Y=y){
  mean(Y == (predict(mod)>0) )
}


mod_c = fitModel_log(x,y)
acc = accuracy(mod_c)
print(paste("Accuracy:",acc))

#' Wow! That's an accurate model! But does it mean we're really achieving good class separation?
#' Let's target shuffle it and see how significant this result really is.

n=1e3
#+ message=F, warning=F
results_c = tShuffle(n, x, y, fitModel_log, accuracy, replace=TRUE)

#' Visualize results of target shuffling
plot(density(results_c$values), xlim=c(0,1), main='KDE of Target Shuffling Results')
abline(v=accuracy(mod_c), lty=2, col='red')
legend('topleft', c('Target Shuffled Accuracy', 'Observed Accuracy'), lty=1:2, col=1:2)

#' Our model sure doesn't look so special now.

print(paste("Estimated p-value:", results_c$est_pval))
summary(results_c$values)

#' ### Bootstrap
#' 
#' Target shuffling gives us a distribution over the null hypothesis. The *bootstrap* 
#' technique gives us a distribution over model solutions and/or evaluation statistics,
#' AKA distributions over the alternative hypothesis. We estimated our p-value by 
#' comparing a unique model solution against our distribution of null hypotheses, but
#' we can actually infer a distribution over p-values, giving us a confidence interval
#' on our p-value (!!!)

boot_sample = function(x){
  n = nrow(x)
  ix = sample(n, replace=TRUE)
  x[ix,]
}

boot_stat = function(k, x, y, fitModel, stat){
  results = rep(NULL, k)
  full_dat = cbind(y,x)
  for(i in 1:k){
    boot_dat = boot_sample(full_dat)
    xb = boot_dat[,2:(NCOL(x)+1)]
    yb = boot_dat[,1]
    results[i] = stat(fitModel(xb, yb))
  }
  results
}

# results_a = tShuffle(n, iris$Petal.Width, iris$Petal.Length, fitModel, stat, replace=TRUE)
boot_r2 = boot_stat(n, iris$Petal.Width, iris$Petal.Length, fitModel, stat)


plot(density(results_a$values), xlim=c(0,1), main='KDE of Target Shuffling Results')
lines(density(boot_r2), col='blue')
abline(v=stat(mod_a), lty=2, col='red')
legend('top', c('Target Shuffled R2', 'Observed R2', 'Bootstrapped R2'), lty=c(1,2,1), col=c(1,'red', 'blue'))

#' I like this. Let's wrap the whole process.

simulate_distributional_hypothesis_test = function(k, x, y, fitModel, stat, plt=TRUE){
  null_dist = tShuffle(k, x, y, fitModel, stat, replace=TRUE)
  alt_dist  = boot_stat(k, x, y, fitModel, stat)
  mod = fitModel(x,y)
  obs_stat = stat(mod)
  p_dist = sapply(alt_dist, function(v) 1 - mean(v>null_dist$values))
  p_thsuffle = null_dist$est_pval
  if(plt){
    plot(density(null_dist$values), xlim=range(c(null_dist, alt_dist)), main="Target shuffling vs. bootstrap")
    lines(density(alt_dist), col='blue')
    abline(v=obs_stat, lty=2, col='red')
    legend('top', c('Target Shuffled stat', 'Observed stat', 'Bootstrapped stat'), lty=c(1,2,1), col=c(1,'red', 'blue'))
  }
  list(null_hypothesis=null_dist$values, 
       alternative_hypothesis=alt_dist, 
       fitted_stat=obs_stat, 
       fitted_model=mod, 
       fitted_pval=extract_pval(mod), 
       pvalue_distribution=p_dist,
       tshuffle_pvalue=p_thsuffle)
}

#' Where we have wel defined significance, the two distributions are well separated.

sim_dist = simulate_distributional_hypothesis_test(n, iris$Petal.Width, iris$Petal.Length, fitModel, stat)

#' Where we don't have strong significance, there is overlap in the target shuffled and bootstrapped distributions, and
#' we get a range (distribution) of pvalues

sim_dist2 = simulate_distributional_hypothesis_test(n, iris$Sepal.Width, iris$Sepal.Length, fitModel, stat)

plot(density(sim_dist2$pvalue_distribution), main="p-value distribution", xlim=c(0,1))
abline(v=sim_dist2$fitted_pval, lty=2, col="red")
legend('topright', c('Estimated p-value distribution', 'Analytic p-value'), lty=c(1,2), col=c(1,'red'))

#' The median of our estimation distribution is pretty close to our analytic and target-shuffled p-values.
sim_dist2$fitted_pval
sim_dist2$tshuffle_pvalue
quantile(sim_dist2$pvalue_distribution, c(.05, .5, .95))

#' interesting, the mode and mean are not.
dens = density(sim_dist2$pvalue_distribution)
dens$x[which.max(dens$y)] # pval distr mode
mean(sim_dist2$pvalue_distribution) # pval distr mean

#' being a bit more traditional, let's look at the distribution of the difference between the null and the alternative
#' hypothesis. If this distribution contains 0 at our significance level of interest, we fail to reject the null.
dist_diff = sim_dist2$alternative_hypothesis - sim_dist2$null_hypothesis
plot(density(dist_diff))
quantile(dist_diff, c(.05, .5, .95))


#' ### Discussion
#'
#' This obviously invites the question: how useful is a confidence bound about a p-value? I've certainly never seen this 
#' approach used anywhere, but at face value it doesn't strike me as completely useless. In fact, having computed this, 
#' this seems like a good way of doing things. Why shouldn't we calculate bounds about our p-values? How useful is a p-value,
#' or really any statistic, in complete isolation? Although this seems reasonable at first, I have to admit: I'm struggling to 
#' find real value in this range I've constructed. My initial result from target shuffling against a single point estimate for
#' my statistics demonstrated that my model was not significant at a 10% threshold. Querying the p-value distribution told me that
#' there are random models that are significant (the tail of the distribution that lies outside of the range of the target shuffled
#' statistic) and there are random models that are stringly not significant (the distributional overlap). So what?