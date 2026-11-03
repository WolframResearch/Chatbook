## Training a classifier

[`Classify`](paclet:ref/Classify) is the quickest way to train a classifier in Wolfram Language. It automatically chooses a method, preprocesses the features, and tunes hyperparameters.

### A first example

```wl
trainingData = {
  {5.1, 3.5} -> "setosa", {4.9, 3.0} -> "setosa", {4.7, 3.2} -> "setosa",
  {7.0, 3.2} -> "versicolor", {6.4, 3.2} -> "versicolor", {6.9, 3.1} -> "versicolor",
  {6.3, 3.3} -> "virginica", {5.8, 2.7} -> "virginica", {7.1, 3.0} -> "virginica"
};

c = Classify[trainingData]
```

Then apply it to new data:

```wl
In[3]:= c[{6.0, 3.0}]

Out[3]= "versicolor"

In[4]:= c[{6.0, 3.0}, "Probabilities"]

Out[4]= <|"setosa" -> 0.0412, "versicolor" -> 0.6301, "virginica" -> 0.3287|>
```

### Using a real dataset

For a more realistic example, use the full Fisher iris dataset from `ExampleData`:

```wl
iris = ExampleData[{"MachineLearning", "FisherIris"}, "Data"];
{train, test} = TakeDrop[RandomSample[iris], 100];
c = Classify[train, Method -> "RandomForest"]
```

### Measuring performance

Use [`ClassifierMeasurements`](paclet:ref/ClassifierMeasurements) to evaluate the classifier on the test set:

```wl
cm = ClassifierMeasurements[c, test];
cm["Accuracy"]
cm["ConfusionMatrixPlot"]
```

Some of the available measurements:

| Property | Meaning |
|:---------|:--------|
| `"Accuracy"` | fraction of correctly classified examples |
| `"Precision"` | per class: $\frac{TP}{TP + FP}$ |
| `"Recall"` | per class: $\frac{TP}{TP + FN}$ |
| `"F1Score"` | harmonic mean of precision and recall |
| `"LogLikelihood"` | $\sum_i \log P(y_i \mid x_i)$ |
| `"ConfusionMatrixPlot"` | visual confusion matrix |

The $F_1$ score is defined as

$$F_1 = 2 \cdot \frac{\text{precision} \cdot \text{recall}}{\text{precision} + \text{recall}}$$

### Choosing a method

`Classify` supports many methods. If you don't specify one, it picks automatically, but you can compare them:

```wl
methods = {"LogisticRegression", "RandomForest", "NearestNeighbors",
   "SupportVectorMachine", "GradientBoostedTrees", "NeuralNetwork"};
results = AssociationMap[
  ClassifierMeasurements[Classify[train, Method -> #], test, "Accuracy"] &,
  methods
]
```

Typical results for this dataset:

| Method | Accuracy | Training time |
|:-------|---------:|--------------:|
| `"LogisticRegression"` | 0.96 | 0.4 s |
| `"RandomForest"` | 0.94 | 0.9 s |
| `"NearestNeighbors"` | 0.96 | 0.2 s |
| `"SupportVectorMachine"` | 0.98 | 0.6 s |
| `"GradientBoostedTrees"` | 0.92 | 1.8 s |
| `"NeuralNetwork"` | 0.96 | 3.1 s |

With only 50 test examples, a difference of 0.02 is a single example, so don't read too much into small differences.

### Features of different types

`Classify` handles numbers, strings, images, and mixed data automatically:

```wl
sentiment = Classify[{
  "I love this product" -> "positive",
  "Terrible experience, would not recommend" -> "negative",
  "Works great and arrived quickly" -> "positive",
  "Broke after two days" -> "negative"
}];
sentiment["Pretty good overall"]
```

For text, there are also pretrained classifiers:

```wl
Classify["Sentiment", "The weather today is wonderful"]
(* "Positive" *)
```

### Beyond `Classify`

When you need full control over the model, use the neural network framework:

1. Define the network with `NetChain` or `NetGraph`.
2. Train it with [`NetTrain`](paclet:ref/NetTrain).
3. Evaluate it with `NetMeasurements`.

```wl
net = NetChain[{LinearLayer[16], Ramp, LinearLayer[3], SoftmaxLayer[]},
  "Input" -> 4, "Output" -> NetDecoder[{"Class", {"setosa", "versicolor", "virginica"}}]];
trained = NetTrain[net, train, MaxTrainingRounds -> 200];
NetMeasurements[trained, test, "Accuracy"]
```

> **Tip:** For small tabular datasets like this one, `Classify` is usually as good as a hand-built network and much faster to set up. Neural networks shine on large datasets of images, audio, and text.
