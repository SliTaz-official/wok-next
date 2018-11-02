#!/bin/sh

. /etc/init.d/rc.functions

action "Switching on ISA PNP ethernet card"

# io 0x360..0x250 by 0x10, irq 15 12 11 10 9 7 6 5 4 3

for io in $(seq 360 -10 250); do
	for irq in 15 12 11 10; do
		pnpdump \
		| busybox awk -virq=$irq -vio=$io '
			BEGIN {s=0}
			/CONFIGURE CSC6040/
				{s=1}
			{
				if (s==0) print;
				else if (/INT 0/)
					printf("(INT 0 (IRQ %s (MODE +E)))\n", irq);
				else if (/IO 0/)
					printf("(IO 0 (SIZE 16) (BASE 0x0%s) (CHECK))\n", io);
				else if (/ACT Y/)
					{s=0; print "(ACT Y)"}
				else print
			}' \
		> /etc/isapnp.conf

		if isapnp /etc/isapnp.conf >/dev/null 2>&1; then
			modprobe cs89x0 io=0x$io irq=$irq >/dev/null 2>&1
			break 2
		fi
	done
done

status
