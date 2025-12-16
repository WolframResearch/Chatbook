# Entity > Basic Entity Usage
paclet:ref/Entity#c1

Use natural language input to retrieve an `Entity` object:

```wl
In[1]:= entity = ["domestic cat", Entity]

During evaluation of In[1]:= [INFO] Interpreted "domestic cat" as: Entity["TaxonomicSpecies", "FelisCatus::ddvt3"]

Out[1]= Entity["TaxonomicSpecies", "FelisCatus::ddvt3"]
```

Get a list of available properties for the entity:

```wl
In[2]:= properties = entity["Properties"]

Out[2]= {EntityProperty["TaxonomicSpecies", "AlternateCommonNames"], ..., EntityProperty["TaxonomicSpecies", "Order"], ..., EntityProperty["TaxonomicSpecies" -> "Eukaryote" -> "Animal" -> "Mammal", "AgeOfWeaning"]}
```

Use `CanonicalName` to convert the `EntityProperty` objects to their names:

```wl
In[3]:= CanonicalName[properties]

Out[3]= {"AlternateCommonNames", ..., "Order", ..., "AgeOfWeaning"}
```

Use any of these property names (or a list of them) to retrieve the corresponding value(s):

```wl
In[4]:= order = entity["Order"]

Out[4]= Entity["TaxonomicSpecies", "Carnivora::8x672"]
```

*Note:* `entity["property"]` is equivalent to `EntityValue[entity, "property"]`.

Convert `Entity` objects to their plain text names with `CommonName`:

```wl
In[5]:= CommonName[order]

Out[5]= "carnivores"
```

Get all property names and their values as an association:

```wl
In[6]:= KeyMap[CanonicalName, entity["NonMissingPropertyAssociation"]]

Out[6]= <|"AlternateCommonNames" -> {"cat", "house cat"}, ..., "AgeOfWeaning" -> Quantity[Interval[{1.4695, 1.999}], "Months"]|>
```

Get the value of a property directly using natural language input:

```wl
In[7]:= ["domestic cat alternate common names"]

During evaluation of In[7]:= [INFO] Interpreted "domestic cat alternate common names" as: Entity["TaxonomicSpecies", "FelisCatus::ddvt3"][EntityProperty["TaxonomicSpecies", "AlternateCommonNames"]]

Out[7]= {"cat", "house cat"}
```