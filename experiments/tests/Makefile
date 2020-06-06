all:
	@for f in $(shell ls ./*.dot); do dot -Tpng $${f} > $${f}.png; done

clean:
	rm *.dot
	rm *.png
