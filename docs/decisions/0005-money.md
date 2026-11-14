# 0005. Money: strings in JSON, NUMERIC in Postgres, currency stored separately

**Status:** Accepted (contracts and schema v0.2)

## Context
Floating-point numbers silently lose precision, which is unacceptable for invoices.

## Decision
In Python, money is Decimal. In JSON it is a string such as "420000.00". In Postgres it is NUMERIC(14,2), with a separate 3-letter currency code. Quantities use NUMERIC(12,3). Contract validators reject JSON floats.

## Why
Strings and NUMERIC preserve exact values end to end.

## Trade-offs
Clients must send strings; a float is rejected with a clear error. Currency conversion is out of scope.

## Interview talking point
How do you represent money safely across a JSON API?

## Revisit when
We add multi-currency totals (then add exchange-rate handling as its own design).
