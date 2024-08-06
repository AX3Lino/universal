# Early Universal Automation for Multis

A post by Julia (vlamonster) and AX3Lino.

## Introduction

This post outlines a method to integrate multi-block machines into your Applied Energistics system in a universal and
scalable manner. By "universal," we mean that the machine can handle any recipe it is capable of processing. This
includes recipes involving programmed circuits and other non-consumable items (referred to as NCs). Additionally, the
setup is highly scalable and works seamlessly with (dual) P2P interfaces if more parallel processing is required.

As far as we are ware, this setup has minimal overhead and is TPS-friendly, though it has not yet been extensively
tested.

Constructive feedback is welcome, but please keep it related to this post.

## The Idea

This section explains how the setup works, though it's not necessary to understand it to recreate it. Read this if you
want to make changes or understand the process.

To make our machines perform arbitrary recipes, we need to send non-consumables (NCs) along with the inputs. This poses
two problems: teaching the system how to handle these recipes and moving the NC from the input bus, as it is not
automatically moved to the output upon recipe completion.

### Teaching the System

The first problem has a straightforward solution with some caveats. We add the NC to *both* the input and output of
patterns. This requires adding copies of the NC to your system. The number of NCs needed depends on the potential
parallelism of your system. For instance, if an item requires both iron plates and steel plates using circuit 1 as NC,
the system will need 2 copies of circuit 1 to start the craft. If your system has N bending machines, you should
have `max(N, 2)` copies of circuit 1 to use all available parallelism.

There are some nuances here that you may need to be aware of. AE2 considers different nodes in the crafting tree that
refer to the same item to be parallelizable. For example the following crafting tree will require two copies of `NC`
because it thinks it can *theoretically* parallelize here.

```
B + C -> D
├── A + NC -> B
└── B -> C
    └── A + NC -> B
```

Lastly, AE2 will try to re-use outputs when it sees it can repeat any particular recipe. For this reason you will need a
way to convince the system that it is constantly being returned relevant NCs for parallelized recipes. This can easily
be achieved by putting an export bus on an interface with the relevant NCs.

### Moving the Non-Consumables

The second problem can be solved using an OpenComputers computer. Input buses have directional I/O, so we need a way to
both pull and push to it. This is achieved using a Transvector Interface from Thaumic Tinkerer, binding it to the input
bus to get another copy of the input face. The computer uses a Transposer to move the NCs around. By placing a
Transposer adjacent to the Transvector Interface and an Interface block from AE2, we can return NCs to the system upon
recipe completion.

### Lua Script

The following snippet from the Lua script checks when ***only*** the NC is left in the subnet and moves it accordingly.
The Transposer should be adjacent to the input bus (and input hatch, if there is one) with the highest priority in the
subnet. Additionally, the input bus must sort its items so that the NC eventually appears in the first slot.

```Lua
    for _, transposer in pairs(transposers) do
      local item = transposer.getStackInSlot(transposer.inputBusSide, 1)
      if item and nonConsumables[item.label] then
        if not transposer.inputHatchSide or transposer.getFluidInTank(transposer.inputHatchSide, 1).amount == 0 then
          transposer.transferItem(transposer.inputBusSide, transposer.interfaceSide, 1, 1, 1)
        end
      end
    end
```

## The Setup

### Needed Items

- Computer/Server (depending on number of components)
- Transposer
- p2p tunnels
- ME Interface (Block)
- Transvector Interface
- *Optional: Advanced Blocking Card if using subnets*

### Steps

1. Put transposer adjacent to
    * ME Interface (Block)
    * Transvector Interface (linked to input bus with the highest priority, matching the input facing)
    * *Optional: Input hatch with the highest priority*
2. Connect Computer/Server to transposers using OpenComputer p2p tunnels.
3. *Optional: set Advanced Blocking Card to strict mode on subnet side and (p2p) interface looking into subnet with
   blocking mode enabled.*
4. Set your home directory up like in https://github.com/Vlamonster/universal and run `universal` when your system has
   booted.

### Pitfalls

Watch out for accidentally putting other GT:NH blocks next to the Transposer, as the computer may mess up. For example,
a combustion generator could accidentally be seen as an input hatch!
