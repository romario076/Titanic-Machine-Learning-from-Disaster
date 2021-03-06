
library(ggplot2)
library(tree)
library(caret)
library(party)
library(randomForest)
library(rattle)
library(rpart.plot)
library(RColorBrewer)
library(nnet)
library(VIMGUI)
library(knitr)
 
#### Loading data
 
train<- read.csv("train.csv")
test<- read.csv("test.csv")
sub<- read.csv("genderclassmodel.csv")
test$Age<- as.integer(round(test$Age,0))
#Levels for Embarked 
test$Embarked<- factor(test$Embarked, levels=c("","C","Q","S"))
kable(head(train), format = "markdown")
str(train)
variables<- read.table("variables.txt", header=T, sep="")
 
#Descriptions

kable(variables, format = "markdown")

#Let’s start with the name field. And build a new predictive variables.
test$Survived <- NA
combi <- rbind(train, test)
combi$Name <- as.character(combi$Name)
combi$Title <- sapply(combi$Name, FUN=function(x) {strsplit(x, split='[,.]')[[1]][2]})
combi$Title <- sub(' ', '', combi$Title)
combi$Title[combi$Title %in% c('Mme', 'Mlle')] <- 'Mlle'
combi$Title[combi$Title %in% c('Capt', 'Don', 'Major', 'Sir')] <- 'Sir'
combi$Title[combi$Title %in% c('Dona', 'Lady', 'the Countess', 'Jonkheer')] <- 'Lady'
combi$Title <- factor(combi$Title)
combi$FamilySize <- combi$SibSp + combi$Parch + 1
combi$Surname <- sapply(combi$Name, FUN=function(x) {strsplit(x, split='[,.]')[[1]][1]})
combi$FamilyID <- paste(as.character(combi$FamilySize), combi$Surname, sep="")
combi$FamilyID[combi$FamilySize <= 2] <- 'Small'
combi$FamilyID <- factor(combi$FamilyID)
```
 
#This step will be very useful when we well be using Random forest algoritm. WE create variable "Familysize"="Parch"+"Sibsp"+1. But this variable has lots of cathegories, in some cases it's problematic. So, we add new variable FamilyId2 that contains less cathegories than variable FamilyId. We substitute families that has less than three members as "small". Random Forest algoritm is imposible for variables that have more than 53 cathegories.
#We create "combine set", that is a union of test and train sets. He has 1309 observations, it means that abroad were 1309 passengers.

combi$FamilyID2 <- combi$FamilyID
combi$FamilyID2 <- as.character(combi$FamilyID2)
combi$FamilyID2[combi$FamilySize <= 3] <- 'Small'
combi$FamilyID2 <- factor(combi$FamilyID2)

train <- combi[1:891,]
test <- combi[892:1309,]

 
###Missing values

apply(combi, 2, function(x) sum(is.na(x)*1))
matrixplot(combi[,c(-4,-15,-16,-17)])
legend("topright", legend=c("NA's"), fill=c("red"))

 
#There are lots of missing values, if we later want to make a statistical analysis of this data, it will be impossible to realize, that's why, we must to substitute this missing values by new values, one way is to predict new values by using random forest or decision tree.

trainAgeNa<- train[is.na(train$Age),c(-4,-9,-11,-15)]
trainAge<- train[!is.na(train$Age), c(-4,-9,-11,-15) ]
predAge<- rpart(Age ~ Pclass+Sex+SibSp+Parch+Fare+
                  Embarked+Survived+Title+FamilyID, data=trainAge[,c(-1,-13)],method="anova")
forpred<- predict(predAge, trainAgeNa[,c(-1,-5,-13)] )
NewAge<- round(round(forpred,0))
trainAgeNa$Age=NewAge
train<- data<- merge(trainAgeNa, trainAge, all=T)

fare<- as.numeric(rownames(test[is.na(test$Fare),]))
m<- mean(test$Fare[-153])
test$Fare[153]<- m
testAgeNa<- test[is.na(test$Age), c(-4,-11,-15)]
testAge<- test[!is.na(test$Age), c(-4,-11,-15)]
predAgeT<- rpart(Age ~ Pclass+Sex+SibSp+Parch+Fare+Embarked+
                   Title+FamilyID, data=testAge[,c(-1,-2,-12,-14)], method="anova")
AgeT<- predict(predAgeT, testAgeNa[,c(-1,-2,-5,-14)])
NewAgeT<- round(round(AgeT,0))
testAgeNa$Age=NewAgeT
test<- data2<- merge(testAgeNa, testAge, all=T)

#fit2 <- rpart(Age ~ Pclass + Sex + SibSp + Parch + Fare + Embarked + Title + FamilySize,
#                data=combi[!is.na(combi$Age),], method="anova")
#combi$Age[is.na(combi$Age)] <- predict(fit2, combi[is.na(combi$Age),])

####Complete data set without Na's.

test$Survived=NULL
kable(head(train), format = "markdown")

####Missing values prediction. 
#So, move on to the next step.
#One way to measure the prediction ability of a model is to test it on a set of data not used in estimation. Data miners call this a "testing set" and the data used for estimation is the "training set".
 
train$Pclass<- factor(train$Pclass)
test$Pclass<- factor(test$Pclass)
train$SibSp<- factor(train$SibSp)
train$SibSp<- factor(train$SibSp, levels=c(0:5,8))
test$SibSp<- factor(test$SibSp, levels=c(0:5,8))
test1<- test[,c(-7)]
train1<- train
train1$Title<- factor(train1$Title)
test1$Title<- factor(test1$Title, levels=levels(factor(train1$Title)))

#Split data into training and testing sets. And apply **decision tree** algorithm for prediction.

set.seed(56)
y<-createDataPartition(y=train1$Survived, p=0.7, list=F)
training<-train1[y,]
testing<- train1[-y,]

predtree<- rpart(factor(Survived) ~ Pclass+Sex+Age+SibSp+Parch+Fare+Embarked+Title+FamilyID, data=training[,c(-1,-11,-13)], method="class")
fancyRpartPlot(predtree, sub="")
treepred<- predict(predtree,testing[,c(-1,-2,-11,-13)],type="class")
acc<- data.frame(orig=testing[,2], pred=treepred)
cm<- confusionMatrix(acc$pred, acc$orig)
cm$table
cm$overall['Accuracy']

#Let's apply Random Forest algorithm.
 
training$FamilyID2 <- training$FamilyID
training$FamilyID2 <- as.character(training$FamilyID2)
training$FamilyID2[training$FamilySize <= 3] <- 'Small'
training$FamilyID2 <- factor(training$FamilyID2)
testing$FamilyID2 <- testing$FamilyID
testing$FamilyID2 <- as.character(testing$FamilyID2)
testing$FamilyID2[testing$FamilySize <= 3] <- 'Small'
testing$FamilyID2 <- factor(testing$FamilyID2, levels=levels(factor(training$FamilyID2)))
#training$FamilyID=NULL
#testing$FamilyID=NULL
predFor<- randomForest(as.factor(Survived) ~ Pclass+Sex+Age+SibSp+Parch+Fare+Embarked+Title+
                         FamilyID2, data=training[,-1], ntree=800, mtry=2)
forpred<- predict(predFor, testing[,c(-1,-2)],type="class" )
acc2<- data.frame(orig=testing[,2], pred=forpred)
cm2<- confusionMatrix(acc2$pred, acc2$orig)
cm2$table
cm2$overall['Accuracy']
Importance<-predFor
varImpPlot(Importance, col="darkblue", pch=19)

####Forest of conditional inference trees
set.seed(415)
fit1 <- cforest(as.factor(Survived) ~ Pclass + Sex + Age + SibSp + Parch + Fare + Embarked+Title + FamilySize + FamilyID,
               data = training[,-1], controls=cforest_unbiased(ntree=1000, mtry=2))
Prediction1 <- predict(fit1, testing[,c(-1,-2)], OOB=TRUE, type = "response")
acc9<- data.frame(orig=testing[,2], pred=Prediction1)
cm9<- confusionMatrix(acc9$pred, acc9$orig)
cm9$table
cm9$overall['Accuracy']

 
###Test set prediction
#Testing model. So, here we move to next step, from training model to testing. Now let's apply random forest and decision tree to predict "Survived" variable in test set.
 
#Random Forest
#predFin<- randomForest(as.factor(Survived) ~ Pclass+Sex+Age+SibSp+Parch+Fare+Embarked+Title+FamilySize +
#                         FamilyID2, data=train1[,c(-1)], ntree=800, mtry=1, importance=TRUE)
#forpred<- predict(predFin, test1[,-1],type="class" )
#acc3<- data.frame(PassengerId= sub$PassengerId, original=sub$Survived, Survived=forpred)
#cm3<- confusionMatrix(acc3$Survived, acc3$original)
#cm3$table
#cm3$overall['Accuracy']
#Importance<- predFin
#varImpPlot(Importance, col="darkblue", pch=19)

####Logical Regression
t <- multinom(Survived ~ Pclass+Sex+Age+SibSp+Parch+Fare+Embarked, data = train1) 
pp <- as.data.frame(fitted(t))
pred <- predict(t, test1, "probs") 
acc4 <- data.frame(PassengerId= sub$PassengerId, original=sub$Survived, Survived=round(pred,0))
cm4<- confusionMatrix(acc4$Survived, acc4$original)


#cm4$table
#cm4$overall['Accuracy']

####Decision Tree

predtree<- rpart(as.factor(Survived) ~ Pclass+Sex+Age+SibSp+Parch+Fare+Embarked+Title+FamilySize + FamilyID, data=train1[,-1], method="class")
fancyRpartPlot(predtree, sub="")
treepredG<- predict(predtree,test1[,-1],type="class")
acc7<- data.frame(PassengerId= sub$PassengerId, original=sub$Survived, Survived=treepredG)
#cm5<- confusionMatrix(acc7$Survived, acc7$original)
#cm5$table
#cm5$overall['Accuracy']


####Forest of conditional inference trees
 
set.seed(415)
fit <- cforest(as.factor(Survived) ~ Pclass + Sex + Age + SibSp + Parch + Fare + Embarked+Title + FamilySize + FamilyID,
               data = train1[,-1], controls=cforest_unbiased(ntree=700, mtry=2))
Prediction <- predict(fit, test1[,-1], OOB=TRUE, type = "response")
acc6<- data.frame(PassengerId= sub$PassengerId, original=sub$Survived, Survived=Prediction)
cm6<- confusionMatrix(acc6$original, acc6$Survived)
#cm6$table
#cm6$overall['Accuracy']
final<- acc6[,c(1,3)]
head(final,15)
test1$Survived<-final$Survived
data<- rbind(train1, test1)


 Split training set into two sets "Male" and "Female"
```{r,echo=F}
female<- data[which(data$Sex=="female"),]
male<- data[which(data$Sex=="male"),]

 
###Survival that depends on passenger class.

b1<- b<- table(data$Pclass, data$Survived)  
b1<- as.matrix(b1)
b1S<- data.frame(Class=c(1:3), Amount=rowSums(b1), Died=b1[,1], Survived=b1[,2], Probability=b1[,2]/rowSums(b1))
kable(b1S, format = "markdown")
bar<- barplot(t(b), beside=T,col=c("steelblue", rgb(0, 1, 0, 0.5)), main="Survival by passenger class", xlab="Passenger Class survival", ylab="Amount")
legend("topleft", legend=c("Died", "Survived"), fill=c("steelblue", rgb(0, 1, 0, 0.5)))

 
####For Male

b2<-k<- table(male$Pclass, male$Survived)  
b2<- as.matrix(b2)
b2S<- data.frame(Class= factor(c(1:3)), Died=b2[,1], Survived=b2[,2], Probability=b2[,2]/rowSums(b2))
kable(b2S, format = "markdown")
bar<- barplot(t(k), beside=T,col=c("steelblue", rgb(0, 1, 0, 0.5)), main="Survival by class for Male", xlab="Passenger Class", ylab="Amount")
legend("topleft", legend=c("Died", "Survived"), fill=c("steelblue", rgb(0, 1, 0, 0.5)))

####For Female

b3<-k2<- table(female$Pclass, female$Survived)  
b3<-k2<- table(female$Pclass, female$Survived)  
b3<- as.matrix(b3)
b3S<- data.frame(Class=factor(c(1:3)), Died=b3[,1], Survived=b3[,2], Probability=b3[,2]/rowSums(b3))
kable(b3S, format = "markdown")
bar<- barplot(t(k2), beside=T, col=c("steelblue", rgb(0, 1, 0, 0.5)), main="Survival by class for Female", xlab="Passenger Class", ylab="Amount")
legend("topright", legend=c("Died", "Survived"), fill=c("steelblue", rgb(0, 1, 0, 0.5)))

theme_set(theme_gray(base_size = 17))  
ggplot(b2S, aes(Class,Probability, group=1))+geom_line(aes(color="Male"), lwd=1)+
  geom_point(aes(), size=2)+geom_line(data=b3S, aes(Class, Probability,group=1, col="Female"),lwd=1)+
  geom_point(data=b3S,aes(), size=2)+ggtitle("Survival by passenger class")+  theme(legend.title = element_text(color="blue", size=16, face="bold"))+
  scale_color_discrete(name="Sex")

 
###Survival rate by Age

age<- function(data) {
data28<- data[which(data$Age<=28),]
data12<- data[which(data$Age<=12),]
data30<- data[which(data$Age>28),]
d28<-as.matrix(table(data28$Survived))
d12<- as.matrix(table(data12$Survived))
d30<- as.matrix(table(data30$Survived))
am<- c(sum(d28),sum(d30), sum(d12))
die<- c(d28[1],d30[1],d12[1])
surv<- c(d28[2],d30[2],d12[2])
result<- data.frame(Age=c("Less28","Greater28","Less12"), Amount=am, Died=die, Survived=surv,
                    Probability=surv/am)
return(result)}

####General case

generalAge<-age(data)
kable(generalAge, format = "markdown")

 
####For Female

femaleAge<-age(female)
kable(femaleAge, format = "markdown")


 
####For Male

maleAge<- age(male)
kable(maleAge, format = "markdown")

data1<-data
data1$Survived<- factor(data1$Survived, labels=c("Died","Survived"))
theme_set(theme_gray(base_size = 17))  
g<- ggplot(data1, aes(Age, color=factor(Survived),fill=factor(Survived)))+ geom_density(alpha=0.2)+
  theme(legend.title=element_blank())+ggtitle("Survival by Age Density plot")
g

 
###Survival that depends on Fare
  
 Let's see on deviation of ticket price from the mean price.

summary(data$Fare)

theme_set(theme_gray(base_size = 17))  
g1<- ggplot(data1, aes(Fare, color=factor(Survived), fill=factor(Survived)))+ geom_density(alpha=0.3)+
  theme(legend.title=element_blank())+ggtitle("Survival by Fare Density plot")
g1


fare<- function(data) {
  dataL<- data[which(data$Fare<=30),]
  dataG<- data[which(data$Fare>30),]
  dG<-as.vector(table(dataG$Survived))
  dL<- as.vector(table(dataL$Survived))
  am<- c(sum(dG),sum(dL))
  die<- c(dG[1],dL[1])
  surv<- c(dG[2],dL[2])
  result<- data.frame(Fare=c("Greater30","Less30"), Amount=am, Died=die, Survived=surv,
                      Probability=surv/am)
  return(result)}

####General case

fareG<- fare(data)
kable(fareG, format = "markdown")

 
####For Male

fareM<-fare(male)
kable(fareM, format = "markdown")

####For Female

fareF<-fare(female)
kable(fareF, format = "markdown")

###Survival that depends on gender
```{r,echo=F}
gender<- as.matrix(table(data$Sex, data$Survived))
genderS<- data.frame(Sex=c("female","male"), Died=gender[,1], Survived=gender[,2], Probability=gender[,2]/rowSums(gender))
rownames(genderS)=NULL
kable(genderS, format = "markdown")

 
###Survival depends on Embarked variable

embarked<- function(data) {
  dataL<- data[which(data$Embarked=="C"),]
  dataQ<- data[which(data$Embarked=="Q"),]
  dataS<- data[which(data$Embarked=="S"),]
  dL<- as.vector(table(dataL$Survived))
  dQ<- as.vector(table(dataQ$Survived))
  dS<- as.vector(table(dataS$Survived))
  am<- c(sum(dL),sum(dQ),sum(dS))
  die<- c(dL[1],dQ[1],dS[1])
  surv<- c(dL[2],dQ[2],dS[2])
  result<- data.frame(Embarked=c("Cherbourg","Queenstown","Southampton"), Amount=am, Died=die, Survived=surv,
                      Probability=surv/am)
  return(result)}

####General case

embG<- embarked(data)
kable(embG, format = "markdown")

####For Male
```{r,echo=F}
embSM<- embarked(male)
kable(embSM, format = "markdown")

####For Female

embSF<- embarked(female)
kable(embSF, format = "markdown")

###Survival that depends on Family size

child<- as.matrix(table(data$Parch, data$Survived))
childS<- data.frame(Amount=c(0:6), Died=child[1:7,1], Survived=child[1:7,2], Probability= round(child[1:7,2]/rowSums(child[1:7,]),3))

 
####General case

kable(childS, format = "markdown")

####For Female
```{r,echo=F}
childF<- as.matrix(table(female$Parch, female$Survived))
childFS<- data.frame(Amount=c(0:6), Died=childF[1:7,1], Survived=childF[1:7,2],
                     Probability= round(childF[1:7,2]/rowSums(childF[1:7,]),3))
kable(childFS, format = "markdown")

####For Male

childM<- as.matrix(table(male$Parch, male$Survived))
childMS<- data.frame(Amount=c(0:6), Died=childM[1:7,1], Survived=childM[1:7,2], Probability= round(childM[1:7,2]/rowSums(childM[1:7,]),3))
kable(childMS, format = "markdown")

theme_set(theme_gray(base_size = 17)) 
ggplot(childFS, aes(Amount,Probability))+geom_line(aes(color="female"), lwd=1)+geom_point(size=2)+geom_line(data=childMS, aes(Amount, Probability, col="male"),lwd=1)+geom_point(data=childMS,aes(), size=2)+
  theme(legend.title = element_text(color="Darkblue", size=16, face="bold"))+ scale_color_discrete(name="Gender")


###Survival "Title" variable
```{r,echo=F}
title<- as.matrix(table(data$Title, data$Survived))
titleS<- data.frame(Amount=rowSums(title), Died=title[,1], Survived=title[,2], Probability= round(title[,2]/rowSums(title),3))
kable(titleS, format = "markdown")

 
###General table
#Uner each column name we have a probability to survive for male and female respectively.

Pclass<- rbind(data.frame(Class1=round(b2S$Probability[1],3), Class2= round(b2S$Probability[2],3),
                          Class3=round(b2S$Probability[3],3)),
               data.frame(Class1=round(b3S$Probability[1],3), Class2= round(b3S$Probability[2],3), Class3= round(b3S$Probability[3],3)))

Age<- rbind(data.frame(Age_Less28=round(maleAge$Probability[1],3), Age_Greater28= round(maleAge$Probability[2],3),
                          Age_Less12=round(maleAge$Probability[3],3)),
               data.frame(Age_Less28=round(femaleAge$Probability[1],3), Age_Greater28= round(femaleAge$Probability[2],3),
                          Age_Less12=round(femaleAge$Probability[3],3)))

Fare<- rbind(data.frame(TicketPrice_Greater30=round(fareM$Probability[1],3), 
                        TicketPrice_Less30= round(fareM$Probability[2],3)),                
            data.frame(TicketPrice_Greater30=round(fareF$Probability[1],3), 
                       TicketPrice_Less30= round(fareF$Probability[2],3)))

embarked<-  rbind(data.frame(Cherbourg=round(embSM$Probability[1],3), Queenstown = round(embSM$Probability[2],3),
                             Southampton=round(embSM$Probability[3],3)),
                  data.frame(Cherbourg=round(embSF$Probability[1],3), Queenstown= round(embSF$Probability[2],3), Southampton= round(embSF$Probability[3],3)))

family<- rbind(data.frame(Children_0=round(childMS$Probability[1],3), Children_1= round(childMS$Probability[2],3),
                          Children_2=round(childMS$Probability[3],3), Children_3=round(childMS$Probability[3],3)),
               data.frame(Children_0=round(childFS$Probability[1],3), Children_1= round(childFS$Probability[2],3),
                          Children_2=round(childFS$Probability[3],3), Children_3=round(childFS$Probability[3],3)))

  
general<- data.frame( Sex=c("Male", "Female"),cbind(Pclass,Age, Fare,embarked,family) )
kable(general, format = "markdown")
g<- as.data.frame(t(general[,-1]))
colnames(g)<-c("Male", "Female")
g<- g[order(g$Female, decreasing=T),]
par(mar=c(9,4,4,4))
barpl<- barplot(as.matrix(t(g)), beside=T,col=c("royalblue1", "rosybrown1"), las=2,
                main="Survival", ylab="Probability")
legend("topright", legend=c("Male", "Female"), fill=c("royalblue1", "rosybrown1")) 


###Probability table

generalM<- general[1,c(-1,-7)]
matrix<- function(generalM) {
  generalMj<- generalM[1:7]
  generalMi<- generalM[8:14]
  nameMj<- names(generalMj)
  nameMi<- names(generalMi)
  first<-data.frame()
  for (i in 1:7){
    for (j in 1:7){
      first[i,j]<- (generalMj[,nameMj[j]]+ generalMi[,nameMi[i]])/2 
    }  
  }
  rownames(first)<-nameMi
  colnames(first)<-nameMj
  return(first)  }

####For Male

MaleStat<-matrix(generalM)
kable(MaleStat, format = "markdown")

 
####For Female

generalF<- general[2,c(-1,-7)]
FemaleStat<- matrix(generalF)
kable(FemaleStat, format = "markdown")

