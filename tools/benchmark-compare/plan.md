You are given a path to a directory that contains 2 csv files like this:

`x.csv` contains:
```csv
"Benchmark","Mode","Threads","Samples","Score","Score Error (99.9%)","Unit","Param: COUNT","Param: seed"
"org.openjdk.bench.vm.compiler.TypeVectorOperations.TypeVectorOperationsSuperWord.convertD2LBits","thrpt",1,1,4897.299216,NaN,"ops/ms",512,0
```

`x-base.csv` contains:
```csv
"Benchmark","Mode","Threads","Samples","Score","Score Error (99.9%)","Unit","Param: COUNT","Param: seed"
"org.openjdk.bench.vm.compiler.TypeVectorOperations.TypeVectorOperationsSuperWord.convertD2LBits","thrpt",1,1,4660.395241,NaN,"ops/ms",512,0
```

Create a Java 24 program that uses preview features if advantageous, and uses no third party jar dependencies to:

1. Received the folder as argument and read all csv files in a given folder.
2. Name the data in the csv file ending in `-base.csv` as "Base", and data in the other csv file as "Patch".
3. Compute the difference between the performance numbers in percentage.
When the patch has bigger number, use a positive percentage difference.
When the patch has lower number, use a negative percentage difference.
5. Finally, summarise the data to have this format:

```bash
Benchmark                                                             (COUNT)  (seed)   Mode  Cnt      Base     Patch   Units   Diff
TypeVectorOperations.TypeVectorOperationsSuperWord.convertD2LBits         512       0  thrpt       4660.395  4897.299  ops/ms    +5%
```
