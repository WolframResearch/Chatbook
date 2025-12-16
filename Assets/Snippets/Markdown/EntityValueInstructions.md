Use the following information to write Wolfram Language code that involves `Entity`, `EntityClass`, `EntityProperty`, etc. objects.

# Retrieving values for named entities or entity classes

Retrieve a value for a property of a specific entity, entities, or named entity class(es):

```wl
EntityValue[["entity or entity class name(s)", "entity type"], "property canonical name"]
```

Include `"Association"` in the third argument of `EntityValue` when requesting more than one entity, entity group and/or property; this returns an association with `Entity` and/or `EntityProperty` objects as keys:

```wl
EntityValue[["entity or entity group name(s)", "entity type"], {"property canonical name", ...}, "Association"]
```

The full set of valid values for the third argument of `EntityValue` are:

| Value | Description |
| ----- | --- |
| "EntityAssociation" | an association of entities and entity-property values |
| "PropertyAssociation" | an association of properties and entity-property values |
| "EntityPropertyAssociation" | an association in which the specified entities are keys, and values are a nested association of properties and entity-property values |
| "PropertyEntityAssociation" | an association in which the specified properties are keys, and values are a nested association of entities and entity-property values |
| "Dataset" | a dataset in which the specified entities are keys, and values are an association of property names and entity-property values |
| "Association" | a nested association with entity keys on the first level and property keys on the second level |
| "NonMissingPropertyAssociation" | an association of properties and entity-property values with the missing values dropped |
| "NonMissingEntityAssociation" | an association of entities and entity-property values with the missing values dropped |

# Filtering entities by property values

If an `EntityProperty` can be used to perform an `EntityClass` lookup, use this syntax with specified patterns for `selector`:

```wl
EntityList[EntityClass["entity type",
	{
		EntityProperty["entity type", "property canonical name", {"qualifier name" -> "value name"}] -> selector,
		EntityProperty["entity type", "property canonical name", {"qualifier name" -> "value name"}] -> selector,
		...
	}
]]
```

Note that several selectors may be combined in a single `EntityClass` expression. This is usually the most efficient method of filtering entities.

# Converting natural language to Wolfram Language expressions

Unless exceptions are noted in the instructions for a specific `EntityProperty`, NEVER write `Entity[type, name]` expressions yourself; ALWAYS use  syntax, as in the examples shown here, to convert natural language names into valid Wolfram expressions.

i.e. NEVER write `Entity["Building", "EmpireStateBuilding"]` in code; ALWAYS write `["Empire State Building"]`.

Additional examples:

```wl
["Pennsylvania", Entity]
["lanthanide elements", EntityClass]
["30 m", Quantity]
["January 20, 1987", DateObject]
```

In code results, `Missing["UnknownEntity", ...]` indicates that you used an invalid entity standard name. Try again using  syntax.