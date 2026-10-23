# Two-layer network: tanh hidden units and a sigmoid output.
# Trains by stochastic gradient descent on binary cross-entropy.
# Default data is XOR. Pass a CSV of numeric columns whose last column is the target:
#   ./build/network examples/xor.csv

import math as MathLib
import system as Sys

class Dataset {
    list rows

    Dataset() {
        rows = []
    }

    void add(list row) {
        rows.append(row)
    }

    void useXor() {
        add([0.0, 0.0, 0.0])
        add([0.0, 1.0, 1.0])
        add([1.0, 0.0, 1.0])
        add([1.0, 1.0, 0.0])
    }

    int load(String path) {
        Sys.File input = Sys.File(path, "r")
        list lines = input.readLines()
        input.close()
        int accepted = 0
        int lineIndex = 0
        while (lineIndex < lines.length) {
            String line = lines[lineIndex]
            line = line.trim()
            if (line.length > 0 and not line.startsWith("#")) {
                list parts = line.split(",")
                list row = []
                bool ok = true
                int column = 0
                while (column < parts.length) {
                    String cell = parts[column]
                    try {
                        row.append(cell.trim().toFloat())
                    } except() as error {
                        ok = false
                        print(format("skipping {} ({})\n", line, error))
                    }
                    column = column + 1
                }
                if (ok and row.length >= 2) {
                    if (rows.length == 0 or row.length == width()) {
                        rows.append(row)
                        accepted = accepted + 1
                    }
                }
            }
            lineIndex = lineIndex + 1
        }
        return accepted
    }

    int width() {
        if (rows.length == 0) {
            return 0
        }
        list first = rows[0]
        return first.length
    }

    int features() {
        int columns = width()
        if (columns == 0) {
            return 0
        }
        return columns - 1
    }
}

class Network {
    MathLib.Math math
    int inputCount
    int hiddenCount
    list hiddenWeights
    list hiddenBias
    list outputWeights
    list hidden
    float outputBias
    int seed

    Network(int inputs, int hiddenUnits) {
        math = MathLib.Math()
        inputCount = inputs
        hiddenCount = hiddenUnits
        hiddenWeights = []
        hiddenBias = []
        outputWeights = []
        hidden = []
        outputBias = 0.0
        seed = 17
        int weightCount = hiddenUnits * inputs
        int index = 0
        while (index < weightCount) {
            hiddenWeights.append(nextWeight())
            index = index + 1
        }
        index = 0
        while (index < hiddenUnits) {
            hiddenBias.append(nextWeight())
            outputWeights.append(nextWeight())
            hidden.append(0.0)
            index = index + 1
        }
    }

    float nextWeight() {
        seed = (seed * 13 + 7) % 10007
        int bucket = seed % 9
        return (float(bucket) - 4.0) / 10.0
    }

    float sigmoid(float z) {
        float limited = math.clamp(z, -20.0, 20.0)
        return 1.0 / (1.0 + math.exp(0.0 - limited))
    }

    float crossEntropy(float predicted, float target) {
        float clipped = math.clamp(predicted, 0.0000001, 0.9999999)
        float positive = target * math.log(clipped)
        float negative = (1.0 - target) * math.log(1.0 - clipped)
        return 0.0 - (positive + negative)
    }

    float forward(list row) {
        int unit = 0
        while (unit < hiddenCount) {
            float sum = hiddenBias[unit]
            int input = 0
            while (input < inputCount) {
                float weight = hiddenWeights[unit * inputCount + input]
                float value = row[input]
                sum = sum + weight * value
                input = input + 1
            }
            hidden[unit] = math.tanh(sum)
            unit = unit + 1
        }
        float output = outputBias
        unit = 0
        while (unit < hiddenCount) {
            float activation = hidden[unit]
            float weight = outputWeights[unit]
            output = output + weight * activation
            unit = unit + 1
        }
        return sigmoid(output)
    }

    void learn(list row, float rate) {
        float predicted = forward(row)
        float target = row[inputCount]
        float outputError = predicted - target
        int unit = 0
        while (unit < hiddenCount) {
            float activation = hidden[unit]
            float outputWeight = outputWeights[unit]
            float hiddenError = outputError * outputWeight * (1.0 - activation * activation)
            int input = 0
            while (input < inputCount) {
                int index = unit * inputCount + input
                float weight = hiddenWeights[index]
                float value = row[input]
                hiddenWeights[index] = weight - rate * hiddenError * value
                input = input + 1
            }
            float bias = hiddenBias[unit]
            hiddenBias[unit] = bias - rate * hiddenError
            outputWeights[unit] = outputWeight - rate * outputError * activation
            unit = unit + 1
        }
        outputBias = outputBias - rate * outputError
    }

    float meanLoss(list rows) {
        if (rows.length == 0) {
            return 0.0
        }
        float total = 0.0
        int index = 0
        while (index < rows.length) {
            list row = rows[index]
            float predicted = forward(row)
            float target = row[inputCount]
            total = total + crossEntropy(predicted, target)
            index = index + 1
        }
        return total / float(rows.length)
    }

    void train(list rows, int epochs, float rate) {
        int epoch = 0
        while (epoch < epochs) {
            if (epoch % 1000 == 0) {
                print(format("epoch {} loss {}\n", epoch, meanLoss(rows)))
            }
            int index = 0
            while (index < rows.length) {
                list row = rows[index]
                learn(row, rate)
                index = index + 1
            }
            epoch = epoch + 1
        }
    }

    void save(String path) {
        Sys.File output = Sys.File(path, "w")
        int index = 0
        while (index < hiddenWeights.length) {
            float value = hiddenWeights[index]
            output.writeLine(format("{}", value))
            index = index + 1
        }
        index = 0
        while (index < hiddenBias.length) {
            float value = hiddenBias[index]
            output.writeLine(format("{}", value))
            index = index + 1
        }
        index = 0
        while (index < outputWeights.length) {
            float value = outputWeights[index]
            output.writeLine(format("{}", value))
            index = index + 1
        }
        output.writeLine(format("{}", outputBias))
        output.close()
    }

    bool load(String path) {
        Sys.File input = Sys.File(path, "r")
        list lines = input.readLines()
        input.close()
        list values = []
        int index = 0
        while (index < lines.length) {
            String line = lines[index]
            line = line.trim()
            if (line.length > 0) {
                values.append(line.toFloat())
            }
            index = index + 1
        }
        int expected = hiddenWeights.length + hiddenBias.length + outputWeights.length + 1
        if (values.length != expected) {
            print(format("weight file has {} values, expected {}\n", values.length, expected))
            return false
        }
        int cursor = 0
        index = 0
        while (index < hiddenWeights.length) {
            float value = values[cursor]
            hiddenWeights[index] = value
            cursor = cursor + 1
            index = index + 1
        }
        index = 0
        while (index < hiddenBias.length) {
            float value = values[cursor]
            hiddenBias[index] = value
            cursor = cursor + 1
            index = index + 1
        }
        index = 0
        while (index < outputWeights.length) {
            float value = values[cursor]
            outputWeights[index] = value
            cursor = cursor + 1
            index = index + 1
        }
        float bias = values[cursor]
        outputBias = bias
        return true
    }
}

start {
    Sys.Process process = Sys.Process()
    Dataset dataset = Dataset()
    if (process.argc() >= 2) {
        String path = process.arg(1)
        int loaded = dataset.load(path)
        print(format("loaded {} rows from {}\n", loaded, path))
    } else {
        dataset.useXor()
        print("using built-in XOR rows\n")
    }
    if (dataset.rows.length == 0 or dataset.features() < 1) {
        print("no training rows\n")
        Sys.Process().exit(1)
    }

    Network network = Network(dataset.features(), 4)
    list rows = dataset.rows
    print(format("initial loss {}\n", network.meanLoss(rows)))
    network.train(rows, 5000, 2.0)
    float loss = network.meanLoss(rows)
    print(format("final loss {}\n", loss))

    bool learned = true
    int index = 0
    while (index < rows.length) {
        list row = rows[index]
        float predicted = network.forward(row)
        float target = row[dataset.features()]
        float gap = predicted - target
        if (gap < 0.0) {
            gap = 0.0 - gap
        }
        if (gap > 0.35) {
            learned = false
        }
        String inputs = ""
        int feature = 0
        while (feature < dataset.features()) {
            float value = row[feature]
            if (feature > 0) {
                inputs.append(",")
            }
            inputs.append(format("{}", value))
            feature = feature + 1
        }
        print(format("{} target {} prediction {}\n", inputs, target, predicted))
        index = index + 1
    }

    String weightPath = "xor.weights"
    network.save(weightPath)
    Network restored = Network(dataset.features(), 4)
    if (restored.load(weightPath)) {
        list sample = rows[0]
        float original = network.forward(sample)
        float again = restored.forward(sample)
        float difference = original - again
        if (difference < 0.0) {
            difference = 0.0 - difference
        }
        print(format("reloaded prediction {}\n", again))
        if (difference > 0.000001) {
            learned = false
        }
    } else {
        learned = false
    }

    if (learned) {
        print("result learned\n")
    } else {
        print("result not learned\n")
    }
}
