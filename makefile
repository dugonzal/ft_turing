NAME = ft_turing

OCAMLFIND = ocamlfind
PACKAGES = yojson

SRC = $(shell ocamldep -sort -I src src/*.ml)
OBJ = $(patsubst src/%.ml, obj/%.cmo, $(SRC))
OBJ_NATIVE = $(patsubst src/%.ml, obj/%.cmx, $(SRC))

OBJ_DIR = obj/

.PHONY: all
all: $(NAME)
$(NAME): deps $(OBJ)
	$(OCAMLFIND) ocamlc -package $(PACKAGES) -linkpkg $(OBJ) -o $(NAME)

obj/%.cmo: src/%.ml
	mkdir -p $(@D)
	$(OCAMLFIND) ocamlc -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@

.PHONY: native
native: deps $(OBJ_NATIVE)
	$(OCAMLFIND) ocamlopt -package $(PACKAGES) -linkpkg $(OBJ_NATIVE) -o $(NAME)

obj/%.cmx: src/%.ml
	mkdir -p $(@D)
	$(OCAMLFIND) ocamlopt -package $(PACKAGES) -I $(OBJ_DIR) -c $< -o $@

.PHONY: deps
deps:
	opam install $(OCAMLFIND) $(PACKAGES) --yes

.PHONY: clean
clean:
	$(RM) -r obj

.PHONY: fclean
fclean: clean
	$(RM) $(NAME)

.PHONY: re
re: fclean
	$(MAKE) all
