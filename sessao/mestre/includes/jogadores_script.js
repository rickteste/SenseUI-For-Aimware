
function desvincular(p) {
    confirmar("Tem certeza?", "Tem certeza que quer desvincular essa ficha?").then(s=>{
        if (s){
            $.post({
                data: {query: "mestre_delete_player", p: p},
                url: "",
            }).done(function () {
                location.reload();
            });

        }
    })
}


function toggleCombate(t) {
    let checked = $(t).attr("aria-checked");
    console.log(checked);
    if (checked === "true") {
        $(t).attr("aria-checked", "false");
        $(t).addClass("btn-outline-warning").removeClass("btn-warning");
        $(t).find(".fa-slash").show()
    } else {
        $(t).attr("aria-checked", "true");
        $(t).addClass("btn-warning").removeClass("btn-outline-warning");
        $(t).find(".fa-slash").hide()
    }
    checked = $(t).attr("aria-checked");
    console.log(checked);
    $.ajax({
        url:"",
        method: "post",
        data:{query:"mestre_toggle_combate","combate":checked},
        success:(d)=>console.log(d),
    })
    $(t).blur();
}


$(() => {


    $('#adicionar').submit(function (e) {
        e.preventDefault();
        var form = $(this);
        $.post({
            url: "",
            data: form.serialize() + "&query=mestre_add_player",
            dataType: "JSON",
            beforeSend: function () {
                $("#adicionar input, #adicionar button").attr('disabled', true);
                $("#adicionar .return").html("<div class='alert alert-warning m-2'><i class='fat fa-spinner fa-spin'></i> Aguarde enquanto verificamos os dados...</div>");
            },
            success: (data) => {
                console.log(data);
                if (data.msg) {
                    if (!data.success) {
                        $("#adicionar .return").html('<div class="alert alert-danger m-2">' + data.msg + "</div>");
                        $("#adicionar input, #adicionar button").attr('disabled', false);
                    } else {
                        if (data.type == 1) {
                            $("#adicionar .return").html('<div class="alert alert-success m-2">' + data.msg + '</div>');
                            setTimeout(function () {
                                $("#adicionar input, #adicionar button").attr('disabled', false);
                            }, 200)
                        } else {
                            $("#adicionar .return").html('<div class="alert alert-success m-2">' + data.msg + ' <a href="https://fichasop.com/?convite=1&email=' + data.email + '">https://fichasop.com/?convite=1&email=' + data.email + '</a></div>');
                            setTimeout(function () {
                                $("#adicionar input, #adicionar button").attr('disabled', false);
                            }, 200)
                        }
                    }
                }
            },
            error: () => {
                $("#adicionar input, #adicionar button").attr('disabled', false);
                $("#adicionar .return").html("<div class='alert alert-danger m-2'>Houve um erro ao fazer a solicitação, contate um administrador!</div>");
            }
        })
    });


    function refreshstatus() {
        $(".principal").each(function () {
            let $this = $("#" + $(this).attr("id"));
            $($this).load('?token=<?=$missao_token?> #' + $(this).attr("id") + '>*')
        })
        setTimeout(refreshstatus, 5000);
    }

    setTimeout(refreshstatus, 1000);
})