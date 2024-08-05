# Early Universal Automation for Multis
A post by Julia (vlamonster) and AX3Lino.

## Introduction
This post describes a way to integrate multi-block machines into your applied energistics system in a *universal* and scalable way. 
Universal here means that the machine can perform *any* recipe the machine can potentially do. 
This in particular means that machines can process recipes for all the different programmed circuits and 
other non-consumed items - which will be referred to as *NCs*.
Furthermore, the setup is very scalable and is easy to use with (dual) p2p interfaces if more parallels are needed.
As far as we know this setup has minimal overhead and is TPS friendly, but this has not yet been extensively tested.

Constructive feedback is welcome, but please keep it to this post.

## The Idea

This section describes how the setup works, but is not necessary to recreate it. Read this if you want to make changes
or understand what is happening.

In order to make our machines perform arbitrary recipes, we will need to send along the NCs with the inputs.
This poses two problems. Firstly, we need to teach the system how to deal with such recipes. 
Secondly, we need to move the NC from the input bus, because it is not automatically moved to the output on recipe completion.

The first problem has a rather simple solution, but comes with some caveats. 
We simply add the NC to *bo[post.md](README)th* the input and the output of patterns.
This comes at the cost of having to add copies of the NC to your system.
The number of NCs of a particular type you will need depends on how many parallels your system could theoretically do.
As an example, if an item is requested that requires both `iron plates` and `steel plates` using `circuit 1` as NC, 
then the system will need 2 copies of `circuit 1` to start the craft.
***However***, if your system has `N` bending machines, then you will want to have `max(N, 2)` copies of `circuit 1` to maximize throughput.
There are some nuances here that you may need to be aware of. 
AE2 considers different nodes in the crafting tree that refer to the same item to be parallelizable.
For example the following crafting tree will require two copies of `NC`
because it thinks it can *theoretically* parallelize here.
- `B + C -> D`
  - `A + NC -> B`
  - `B -> C`
    - `A + NC -> B`

Lastly, AE2 will try to re-use outputs when it sees it can repeat any particular recipe. 
For this reason you will need a way to convince the system that it is constantly being returned relevant NCs for parallelized recipes.
This can easily be achieved by putting an export bus on an interface with the relevant NCs.

The second problem can be solved by using an OpenComputer computer. 
Since input buses have directional I/O, we need a way to both pull and push to it.
This is achieved by using a Transvector Interface from Thaumic Tinkerer and binding it to the input bus to get
another copy of the input face. The computer will need a Transposer to move the NC around.
By putting a Transposer adjacent to the Transvector Interface and Interface block from AE2 we can return NCs to the system upon recipe completion.
But how do we know *when* we should move the NC? This is where some LUA comes in to save the day.
By furthermore positioning the Transposer next to the fluid input hatch (if there are any) we can use some simple code to
check when ***only*** the NC is left in the subet. The logic that figures this out will look like this. 
It is important here that the transposer sees the input bus and input hatch with the *highest* priority in the subnet.
Furthermore, the input bus must sort its items, so that the NC will eventually appear in the first slot.

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
***Needed Items***
- Computer/Server (depending on number of components)
- Transposer
- p2p tunnels
- ME Interface (Block)
- Transvector Interface
- *Optional: Advanced Blocking Card if using subnets*

***Steps***
1. Put transposer adjacent to 
   * ME Interface (Block)
   * Transvector Interface (linked to input bus with the highest priority, matching the input facing)
   * *Optional: Input hatch with the highest priority*
2. Connect Computer/Server to transposers using OpenComputer p2p tunnels.
3. *Optional: set Advanced Blocking Card to strict mode on subnet side and (p2p) interface looking into subnet with blocking mode enabled.*
4. Set your home directory up like in https://github.com/Vlamonster/universal and run `universal` when your system has booted.

***Pitfalls***

Watch out for accidentally putting other GT:NH blocks next to the Transposer, as the computer may mess up. 
For example, a combustion generator could accidentally be seen as an input hatch!